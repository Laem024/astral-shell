#!/usr/bin/env bash
# Root phase is copied and redirected to fixtures; never touches DKMS or sysfs.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
upstream=${1:?Pass the reviewed upstream source tree}
runtime=$(astral_test_scratch power)
trap 'rm -rf -- "$runtime"' EXIT
export HOME=$runtime/home XDG_CACHE_HOME=$runtime/cache
mkdir -p "$HOME"
mkdir -p "$runtime/bin" "$runtime/modules/1-test/build" "$runtime/module" "$runtime/batteries/BAT1" "$runtime/registry/source"
bash scripts/install-msi-ec.sh --stage "$upstream" "$runtime/source"
printf 'Katana GF76 11UD\n' > "$runtime/model"
printf '0.18\n' > "$runtime/module/version"
printf '100\n' > "$runtime/batteries/BAT1/charge_control_end_threshold"
printf 'linux-cachyos\n' > "$runtime/modules/1-test/pkgbase"
touch "$runtime/modules/1-test/build/Makefile"
printf 'installed\n' > "$runtime/dkms-1-test"
export ASTRAL_TEST_DIR=$runtime
sed -e "s|export PATH=/usr/bin:/usr/sbin|export PATH=$runtime/bin:/usr/bin:/usr/sbin|" \
  -e 's/\$EUID == 0/1 == 1/g' \
  -e 's/$(stat -c %u "$stored") == 0/1 == 1/' \
  -e 's/$(stat -c %u "$stored\/$file") == 0/1 == 1/' \
  -e "s|stored=/usr/src/msi-ec-\$version|stored=$runtime/source|" \
  -e "s|registry=/var/lib/dkms/msi-ec/\$version|registry=$runtime/registry|" \
  -e "s|boot=/etc/modules-load.d/msi-ec.conf|boot=$runtime/boot/msi-ec.conf|" \
  -e "s|private_root=/run/astral-shell|private_root=$runtime/private|" \
  -e 's/$(stat -c %u:%a "$private_root") == 0:700/$(stat -c %a "$private_root") == 700/' \
  -e "s|backups=/var/lib/astral-shell/backups|backups=$runtime/backups|" \
  -e "s|/sys/class/dmi/id/product_name|$runtime/model|g" \
  -e "s|/sys/class/power_supply|$runtime/batteries|g" \
  -e "s|/sys/module/msi_ec|$runtime/module|g" \
  -e "s|/usr/lib/modules|$runtime/modules|g" \
  -e "s|/lib/modules|$runtime/modules|g" \
  scripts/install-msi-ec.sh > "$runtime/installer"
cat > "$runtime/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf '1-test\n'
MOCK
cat > "$runtime/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == -Q ]]; then [[ ! -f $ASTRAL_TEST_DIR/missing-$2 ]]; exit; fi
printf 'pacman %s\n' "$*" >> "$ASTRAL_TEST_DIR/events"
MOCK
cat > "$runtime/bin/dkms" <<'MOCK'
#!/usr/bin/env bash
kernel=${@: -1}
case $1 in
  status)
    if [[ -f $ASTRAL_TEST_DIR/dkms-$kernel ]]; then
      printf 'msi-ec/0.18, %s, x86_64: %s\n' "$kernel" "$(cat "$ASTRAL_TEST_DIR/dkms-$kernel")"
    fi
    ;;
  build|install)
    printf '%s %s\n' "$1" "$kernel" >> "$ASTRAL_TEST_DIR/events"
    if [[ $1 == build && -f $ASTRAL_TEST_DIR/build-fail ]]; then exit 1; fi
    if [[ $1 == install ]]; then touch "$ASTRAL_TEST_DIR/external-installed"; fi
    if [[ $1 == build ]]; then printf 'built\n'; else printf 'installed\n'; fi > "$ASTRAL_TEST_DIR/dkms-$kernel"
    ;;
  add) mkdir -p "$ASTRAL_TEST_DIR/registry/source"; printf 'add\n' >> "$ASTRAL_TEST_DIR/events" ;;
  *) exit 1 ;;
esac
MOCK
cat > "$runtime/bin/modprobe" <<'MOCK'
#!/usr/bin/env bash
printf 'modprobe\n' >> "$ASTRAL_TEST_DIR/events"
if [[ -f $ASTRAL_TEST_DIR/native-fail && ! -f $ASTRAL_TEST_DIR/external-installed ]]; then exit 1; fi
mkdir -p "$ASTRAL_TEST_DIR/module"
printf '0.18\n' > "$ASTRAL_TEST_DIR/module/version"
MOCK
cat > "$runtime/bin/modinfo" <<'MOCK'
#!/usr/bin/env bash
printf '%s/modules/1-test/updates/dkms/msi-ec.ko\n' "$ASTRAL_TEST_DIR"
MOCK
cat > "$runtime/bin/depmod" <<'MOCK'
#!/usr/bin/env bash
printf 'depmod %s\n' "$*" >> "$ASTRAL_TEST_DIR/events"
MOCK
chmod +x "$runtime/bin/"*
run() { bash "$runtime/installer" --system "$@"; }
run
[[ $(cat "$runtime/boot/msi-ec.conf") == msi-ec && ! -e $runtime/events ]]
run
[[ ! -e $runtime/events ]]
# The exact legacy LLVM-only config is migrated and backed up once.
sed -i 's/make KERNELRELEASE=/make LLVM=1 KERNELRELEASE=/' "$runtime/source/dkms.conf"
run
rg -Fq 'MAKE[0]="make KERNELRELEASE=${kernelver}"' "$runtime/source/dkms.conf"
backup=("$runtime/backups/"*)
[[ ${#backup[@]} == 1 ]]
rg -Fq 'make LLVM=1' "${backup[0]}"
run
[[ ! -e $runtime/events ]]
# A new installed kernel is built once, while the loaded module stays in use.
mkdir -p "$runtime/modules/2-test/build"
printf 'linux-cachyos\n' > "$runtime/modules/2-test/pkgbase"
touch "$runtime/modules/2-test/build/Makefile"
run
[[ $(cat "$runtime/events") == $'build 2-test\ninstall 2-test\ndepmod -a 2-test' ]]
: > "$runtime/events"
run
[[ ! -s $runtime/events ]]
# Old running headers can be gone after an upgrade; the new kernel still works.
mv "$runtime/modules/1-test" "$runtime/old-kernel"
run
[[ ! -s $runtime/events ]]
# A corrupt source or failed build must stop installation, not claim success.
printf '\n/* tamper */\n' >> "$runtime/source/msi-ec.c"
if run > "$runtime/error" 2>&1; then exit 1; fi
rg -q 'Source differs' "$runtime/error"
cp "$upstream/msi-ec.c" "$runtime/source/msi-ec.c"
printf 'built\n' > "$runtime/dkms-2-test"
run
[[ $(cat "$runtime/events") == $'install 2-test\ndepmod -a 2-test' ]]
: > "$runtime/events"
rm "$runtime/dkms-2-test"
touch "$runtime/build-fail"
if run > "$runtime/error" 2>&1; then exit 1; fi
[[ $(cat "$runtime/events") == 'build 2-test' ]]
rm "$runtime/build-fail"
# Missing dependencies are resolved only when the external driver is needed.
touch "$runtime/missing-dkms"
: > "$runtime/events"
run
rg -q '^pacman -S --needed --noconfirm dkms$' "$runtime/events"
rm "$runtime/missing-dkms"
# Native/other working drivers are not replaced; other models are skipped.
mv "$runtime/source" "$runtime/source.saved"
: > "$runtime/events"
run
[[ ! -s $runtime/events ]]
printf 'Other laptop\n' > "$runtime/model"
run
[[ ! -s $runtime/events ]]
# Native failure signals a download requirement without running package tools.
printf 'Katana GF76 11UD\n' > "$runtime/model"
mv "$runtime/module" "$runtime/module.saved"
rm "$runtime/batteries/BAT1/charge_control_end_threshold"
touch "$runtime/native-fail"
rm -f "$runtime/external-installed"
if run; then exit 1; else [[ $? == 20 ]]; fi
[[ $(cat "$runtime/events") == modprobe ]]
# Full first-install and update flow: emulate the pinned download and sudo.
export ASTRAL_UPSTREAM=$upstream
cat > "$runtime/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
exec "$@"
MOCK
cat > "$runtime/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$ASTRAL_TEST_DIR/events"
if [[ $3 == fetch ]]; then
  [[ ${@: -1} == c8cbd48ed01f5c4fa7e34ff622a66f5a5380c705 ]] || exit 1
elif [[ $3 == checkout ]]; then
  cp "$ASTRAL_UPSTREAM/Makefile" "$ASTRAL_UPSTREAM/Makefile.vars" "$ASTRAL_UPSTREAM/msi-ec.c" "$ASTRAL_UPSTREAM/ec_memory_configuration.h" "$ASTRAL_UPSTREAM/dkms.conf" "$2/"
fi
MOCK
chmod +x "$runtime/bin/sudo" "$runtime/bin/git"
mv "$runtime/old-kernel" "$runtime/modules/1-test"
mv "$runtime/registry" "$runtime/registry.saved"
rm "$runtime/dkms-1-test" "$runtime/dkms-2-test"
: > "$runtime/events"
bash "$runtime/installer" install
rg -q 'git.*c8cbd48ed01f5c4fa7e34ff622a66f5a5380c705' "$runtime/events"
[[ $(cat "$runtime/dkms-1-test") == installed && $(cat "$runtime/module/version") == 0.18 ]]
[[ $(cat "$runtime/boot/msi-ec.conf") == msi-ec ]]
: > "$runtime/events"
bash "$runtime/installer" update
[[ ! -s $runtime/events ]]
printf 'MSI_INSTALL_PASS\n'
