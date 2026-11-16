#!/usr/bin/env bash
# Exercise entry-point wiring with every side effect replaced in a private tree.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch power)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/project/scripts" "$runtime/bin"
cp install.sh "$runtime/project/install.sh"
export ASTRAL_INSTALL_TEST=$runtime
for module in install-packages enable-services manage-configs install-sddm install-power; do
  cat > "$runtime/project/scripts/$module.sh" <<'MOCK'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$ASTRAL_INSTALL_TEST/events"
if [[ ${ASTRAL_FAIL_CONFIG:-false} == true && ${0##*/} == manage-configs.sh ]]; then exit 1; fi
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
done
: > "$runtime/events"
if ASTRAL_FAIL_CONFIG=true bash "$runtime/project/install.sh" update; then exit 1; fi
! rg -q 'sudo|install-power.sh' "$runtime/events"
printf 'POWER_INSTALL_PASS\n'
