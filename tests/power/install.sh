#!/usr/bin/env bash
# Exercise entry-point wiring with every side effect replaced in a private tree.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch power)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/project/scripts" "$runtime/bin"
cp install.sh "$runtime/project/install.sh"
cp scripts/cleanup-install.sh "$runtime/project/scripts/cleanup-install.sh"
export XDG_CACHE_HOME=$runtime/cache
export ASTRAL_INSTALL_TEST=$runtime
for module in install-packages enable-services manage-configs install-sddm install-power; do
  cat > "$runtime/project/scripts/$module.sh" <<'MOCK'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$ASTRAL_INSTALL_TEST/events"
source "${0%/*}/cleanup-install.sh"
temporary=$(astral_install_mktemp unused-XXXXXXXX)
printf 'temporary installation data\n' > "$temporary"
printf '%s\n' "$ASTRAL_INSTALL_WORKDIR" > "$ASTRAL_INSTALL_TEST/last-run"
if [[ ${0##*/} == manage-configs.sh ]]; then
  case ${ASTRAL_FAIL_CONFIG:-false} in
    true) exit 37 ;;
    signal) kill -TERM "$PPID" ;;
  esac
fi
MOCK
done
cat > "$runtime/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf 'sudo\n' >> "$ASTRAL_INSTALL_TEST/events"
exec "$@"
MOCK
chmod +x "$runtime/bin/sudo"
export PATH="$runtime/bin:$PATH"
for mode in install update; do
  : > "$runtime/events"
  bash "$runtime/project/install.sh" "$mode"
  [[ $(cat "$runtime/events") == "install-packages.sh $runtime/project $mode"$'\nenable-services.sh \nmanage-configs.sh apply all\n'"install-sddm.sh $mode"$'\n'"install-power.sh $mode" ]]
  [[ ! -e $(cat "$runtime/last-run") ]]
done
: > "$runtime/events"
result=0
ASTRAL_FAIL_CONFIG=true bash "$runtime/project/install.sh" update || result=$?
[[ $result == 37 && ! -e $(cat "$runtime/last-run") ]]
! rg -q 'sudo|install-power.sh' "$runtime/events"
result=0
ASTRAL_FAIL_CONFIG=signal bash "$runtime/project/install.sh" update || result=$?
[[ $result == 143 && ! -e $(cat "$runtime/last-run") ]]

# Only the exact verified run is removed; other runs and user files survive.
source scripts/cleanup-install.sh
astral_install_begin
first=$ASTRAL_INSTALL_WORKDIR
astral_install_begin
second=$ASTRAL_INSTALL_WORKDIR
mkdir -p "$runtime/preserved/.backups" "$XDG_CACHE_HOME/other-app"
printf 'keep\n' > "$runtime/preserved/.backups/config"
printf 'keep\n' > "$XDG_CACHE_HOME/other-app/cache"
ln -s "$runtime/preserved" "$first/external-link"
mkdir "${first%/*}/staging-unrelated"
bash scripts/cleanup-install.sh "$first"
[[ ! -e $first && -d $second && -d ${first%/*}/staging-unrelated ]]
[[ $(cat "$runtime/preserved/.backups/config") == keep ]]
[[ $(cat "$XDG_CACHE_HOME/other-app/cache") == keep ]]

reject_cleanup() {
  if bash scripts/cleanup-install.sh "$1" > "$runtime/rejection" 2>&1; then
    printf 'Cleanup accepted an unsafe path: %s\n' "$1" >&2
    exit 1
  fi
}
reject_cleanup "$runtime/preserved"
reject_cleanup "${second%/*}"
reject_cleanup "$second/../${second##*/}"
ln -s "$second" "${second%/*}/run-AAAAAAAA"
reject_cleanup "${second%/*}/run-AAAAAAAA"
mv "$second/.astral-install" "$second/marker-backup"
reject_cleanup "$second"
ln -s "$second/marker-backup" "$second/.astral-install"
reject_cleanup "$second"
rm -- "$second/.astral-install"
mv "$second/marker-backup" "$second/.astral-install"
chmod 755 "$second"
reject_cleanup "$second"
chmod 700 "$second"
bash scripts/cleanup-install.sh "$second"
[[ ! -e $second ]]

# Exercise real configuration migration and public commands in the run folder.
astral_install_begin
third=$ASTRAL_INSTALL_WORKDIR
export HOME=$runtime/home XDG_CONFIG_HOME=$runtime/config
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
bash scripts/manage-configs.sh apply quickshell > "$runtime/config-install.log"
bash scripts/manage-configs.sh apply quickshell --module astral-bar > "$runtime/config-module.log"
[[ -f $XDG_CONFIG_HOME/quickshell/settings.json && -x $HOME/.local/bin/astral-bar ]]
[[ $($HOME/.local/bin/astral-bar workspace-count) == 10 ]]
[[ -z $(find "$XDG_CONFIG_HOME" "$HOME/.local/bin" -name '.settings-*' -o -name '.preferences-*' -o -name '.existing-*' -o -name '.astral-*') ]]
bash scripts/cleanup-install.sh "$third"
[[ ! -e $third && -f $XDG_CONFIG_HOME/quickshell/settings.json ]]
printf 'POWER_INSTALL_PASS\n'
