#!/usr/bin/env bash
# Reviewed MSI fallback, shared by install and update. No threshold writes here.
set -euo pipefail
trap 'exit 130' INT
trap 'exit 143' TERM
export PATH=/usr/bin:/usr/sbin
script=$(realpath -- "${BASH_SOURCE[0]}")
source "${script%/*}/cleanup-install.sh"
revision=c8cbd48ed01f5c4fa7e34ff622a66f5a5380c705
version=0.18
stored=/usr/src/msi-ec-$version
registry=/var/lib/dkms/msi-ec/$version
boot=/etc/modules-load.d/msi-ec.conf
backups=/var/lib/astral-shell/backups
fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
  printf 'Usage: install-msi-ec.sh [install|update] | --stage SOURCE NEW_DESTINATION | --system [SOURCE]\n'
}
known_model() { [[ $(cat /sys/class/dmi/id/product_name) == 'Katana GF76 11UD' ]]; }
has_threshold() {
  local battery
  for battery in /sys/class/power_supply/*; do
    [[ -f $battery/charge_control_end_threshold ]] && return 0
  done
  return 1
}
write_config() {
  cat > "$1" <<'DKMS'
PACKAGE_NAME="msi-ec"
PACKAGE_VERSION="0.18"
MAKE[0]="make KERNELRELEASE=${kernelver}"
CLEAN="true"
BUILT_MODULE_NAME[0]="msi-ec"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
DKMS
}
verify_code() {
  (
    cd -- "$1"
    sha256sum --check --strict --quiet <<'HASHES'
4963fafaaf054fb3053b69c9f9f76cd981a9cb6efd7c8cb18bbf56c62c11dba2  Makefile
7fc08409708d897c615862ebc6278b1464ff430c26d1b08bb931773d36791628  Makefile.vars
54f8c30d18f9687e637ee135a254089513209370d4bb0631d86e51f56b5b4bb8  msi-ec.c
16c323a2ce9114555639a51c9a0a9be30adda48591289d28e4dc1be6c713005e  ec_memory_configuration.h
HASHES
  ) || fail "Source differs from reviewed revision $revision."
}
stage_source() {
  local source=$1 destination=$2 file
  [[ -d $source && ! -e $destination ]] || fail 'Source must exist and destination must be new.'
  mkdir -m700 -- "$destination"
  for file in Makefile Makefile.vars msi-ec.c ec_memory_configuration.h dkms.conf; do
    [[ -f $source/$file && ! -L $source/$file ]] || fail "Missing regular source: $file"
    cp -L -- "$source/$file" "$destination/$file"
  done
  verify_code "$destination"
  (
    cd -- "$destination"
    printf '%s\n' 'cc4065e02119c2367e0fbf09d989a389fa3239c4e9a7add10dfae2c1613f4d5b  dkms.conf' | sha256sum --check --strict --quiet
  ) || fail 'Upstream DKMS configuration differs from reviewed source.'
  write_config "$destination/dkms.conf"
}
persist_module() {
  [[ ! -L $boot ]] || fail "Refusing symbolic link: $boot"
  if [[ -f $boot && $(cat "$boot") == msi-ec ]]; then return; fi
  if [[ -f $boot ]]; then
    cp --preserve=mode,timestamps -- "$boot" "$boot.backup-$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  install -d -m755 -- "${boot%/*}"
  printf 'msi-ec\n' > "$boot"
  chmod 644 "$boot"
}
case ${1:-install} in
  --stage)
    [[ $# == 3 && $3 == /* ]] || { usage; exit 2; }
    stage_source "$2" "$3"
    exit
    ;;
  install|update)
    [[ $# -le 1 && $EUID != 0 ]] || { usage; exit 2; }
    if ! known_model; then printf 'MSI fallback skipped: this model has not been reviewed.\n'; exit; fi
    # The root phase first repairs/reuses installed source or tries the native
    # driver. Exit 20 means it needs the pinned upstream source, not a failure.
    if sudo bash "$script" --system; then exit; else result=$?; fi
    [[ $result == 20 ]] || exit "$result"
    command -v git >/dev/null || fail "git is required to download the reviewed MSI source."
    download_root=${ASTRAL_INSTALL_WORKDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/astral-shell/msi}
    [[ $download_root == /* ]] || fail 'XDG cache must be absolute.'
    [[ ! -L $download_root ]] || fail 'Invalid MSI download cache.'
    mkdir -p -m700 -- "$download_root"
    [[ -O $download_root && $(stat -c %a "$download_root") == 700 ]] || fail 'MSI download cache must be private and owned by this user.'
    download=$(astral_install_mktemp -d "$download_root/download-XXXXXXXX")
    trap 'rm -rf -- "$download"' EXIT
    git -C "$download" init --quiet
    git -C "$download" fetch --quiet --depth 1 https://github.com/MControlSuite/msi-ec.git "$revision"
    git -C "$download" checkout --quiet --detach FETCH_HEAD
    sudo bash "$script" --system "$download"
    exit
    ;;
  --system)
    [[ $# -le 2 && $EUID == 0 ]] || { usage; exit 2; }
    ;;
  *) usage; exit 2 ;;
esac
if ! known_model; then printf 'MSI fallback skipped: this model has not been reviewed.\n'; exit; fi
kernel=$(uname -r)
# A native or externally managed driver that already works is left in service.
if [[ ! -e $stored ]]; then
  if has_threshold; then printf 'Battery thresholds already available; external installation skipped.\n'; exit; fi
  if [[ -d /sys/module/msi_ec ]]; then
    printf 'msi_ec is loaded but exposes no thresholds; no module will be forced or replaced.\n'
    exit
  fi
  if modprobe msi-ec; then
    if has_threshold; then persist_module; printf 'Native MSI thresholds available.\n';
    else printf 'Native msi_ec loaded without charge threshold support.\n'; fi
    exit
  fi
  [[ $# == 2 ]] || exit 20
fi
command -v pacman >/dev/null || fail "pacman is required."
if [[ -d /sys/module/msi_ec ]]; then
  [[ -f /sys/module/msi_ec/version && $(cat /sys/module/msi_ec/version) == "$version" ]] \
    || fail 'Another msi_ec version is loaded; no live replacement will be attempted.'
fi
# Never use user-controlled XDG locations for privileged work.
private_root=/run/astral-shell
[[ ! -L $private_root ]] || fail 'Invalid privileged runtime directory.'
if [[ ! -e $private_root ]]; then mkdir -m700 -- "$private_root"; fi
[[ -d $private_root && $(stat -c %u:%a "$private_root") == 0:700 ]] || fail 'Privileged runtime must be root-owned and private.'
private=$(mktemp -d "$private_root/msi-install-XXXXXXXX")
trap 'rm -rf -- "$private"' EXIT
if [[ -e $stored ]]; then
  # Installed source is reused offline, but checked before any DKMS execution.
  [[ -d $stored && ! -L $stored ]] || fail 'Invalid installed MSI source directory.'
  [[ $(stat -c %u "$stored") == 0 ]] || fail 'Installed MSI source must be owned by root.'
  (( (8#$(stat -c %a "$stored") & 0022) == 0 )) || fail 'Installed MSI source must not be writable by group or others.'
  for entry in "$stored"/* "$stored"/.[!.]* "$stored"/..?*; do
    [[ -e $entry || -L $entry ]] || continue
    case ${entry##*/} in
      Makefile|Makefile.vars|msi-ec.c|ec_memory_configuration.h|dkms.conf) ;;
      *) fail "Unexpected installed source entry: $entry" ;;
    esac
  done
  for file in Makefile Makefile.vars msi-ec.c ec_memory_configuration.h dkms.conf; do
    [[ -f $stored/$file && ! -L $stored/$file ]] || fail "Invalid installed source: $file"
    [[ $(stat -c %u "$stored/$file") == 0 ]] || fail "Installed MSI source must be owned by root: $file"
    (( (8#$(stat -c %a "$stored/$file") & 0022) == 0 )) || fail "Installed MSI source is writable by group or others: $file"
  done
  verify_code "$stored"
  write_config "$private/dkms.conf"
  if ! cmp -s -- "$private/dkms.conf" "$stored/dkms.conf"; then
    # Migrate only the exact configuration previously installed by this project.
    # DKMS detects LLVM per kernel; forcing it globally breaks GCC-built LTS.
    sed 's/make KERNELRELEASE=/make LLVM=1 KERNELRELEASE=/' "$private/dkms.conf" > "$private/legacy.conf"
    cmp -s -- "$private/legacy.conf" "$stored/dkms.conf" || fail 'Installed DKMS configuration differs; inspect it before updating.'
    install -d -m755 "$backups"
    backup=$(mktemp "$backups/msi-ec-dkms.conf.XXXXXX")
    install -m644 "$stored/dkms.conf" "$backup"
    install -m644 "$private/dkms.conf" "$stored/dkms.conf"
    printf 'Migrated MSI compiler selection; backup: %s\n' "$backup"
  fi
else
  stage_source "$2" "$private/source"
  install -d -m755 "$stored"
  install -m644 "$private/source/"* "$stored/"
fi
# Resolve prerequisites only for the reviewed fallback. Match headers to installed
# CachyOS kernels; an update may have removed the running kernel's old headers.
required=(dkms clang lld make)
declare -A header_packages=()
for directory in /usr/lib/modules/*; do
  [[ -f $directory/pkgbase ]] || continue
  pkgbase=$(cat "$directory/pkgbase")
  [[ $pkgbase =~ ^linux-cachyos[a-zA-Z0-9_-]*$ ]] || continue
  if pacman -Q "$pkgbase" >/dev/null 2>&1; then header_packages["$pkgbase-headers"]=1; fi
done
(( ${#header_packages[@]} > 0 )) || fail 'No installed CachyOS kernel package was found.'
required+=("${!header_packages[@]}")
missing=()
for package in "${required[@]}"; do
  if ! pacman -Q "$package" >/dev/null 2>&1; then missing+=("$package"); fi
done
if (( ${#missing[@]} )); then pacman -S --needed --noconfirm "${missing[@]}"; fi
if [[ ! -e $registry/source ]]; then dkms add -m msi-ec -v "$version"; fi
kernels=()
for directory in /usr/lib/modules/*; do
  [[ -f $directory/pkgbase && -f $directory/build/Makefile ]] || continue
  pkgbase=$(cat "$directory/pkgbase")
  [[ ${header_packages["$pkgbase-headers"]+present} ]] || continue
  target_kernel=${directory##*/}
  kernels+=("$target_kernel")
  status=$(dkms status -m msi-ec -v "$version" -k "$target_kernel")
  if [[ $status == *': installed'* ]]; then
    printf 'MSI DKMS %s already installed for %s; build skipped.\n' "$version" "$target_kernel"
  else
    if [[ $status != *': built'* ]]; then dkms build -m msi-ec -v "$version" -k "$target_kernel"; fi
    dkms install -m msi-ec -v "$version" -k "$target_kernel"
    depmod -a "$target_kernel"
  fi
done
(( ${#kernels[@]} > 0 )) || fail 'No matching CachyOS headers found; install headers for the installed kernel.'
if [[ ! -d /sys/module/msi_ec ]]; then
  if [[ " ${kernels[*]} " == *" $kernel "* ]]; then
    module=$(modinfo -n msi-ec)
    [[ $module == /lib/modules/"$kernel"/updates/* || $module == /usr/lib/modules/"$kernel"/updates/* ]] \
      || fail "External module was not selected: $module"
    modprobe msi-ec
  else
    printf 'MSI driver installed for the next kernel; the running kernel is no longer installed. Restart when convenient to load it.\n'
  fi
fi
persist_module
if has_threshold; then
  printf 'MSI charge thresholds available. No percentage changed.\n'
elif [[ -d /sys/module/msi_ec ]]; then
  printf 'MSI driver loaded, but hardware exposes no charge thresholds.\n'
else
  printf 'Charge threshold availability will be checked after starting the installed kernel.\n'
fi
