#!/usr/bin/bash
# Check both orchestration modes without writing active config or using sudo.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch power)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/project/scripts/configs" "$runtime/bin"
cp scripts/install-power.sh "$runtime/project/scripts/install-power.sh"
cp scripts/configs/common.sh "$runtime/project/scripts/configs/common.sh"
cp scripts/cleanup-install.sh "$runtime/project/scripts/cleanup-install.sh"
export ASTRAL_SETUP_TEST=$runtime
cat > "$runtime/bin/bash" <<'MOCK'
#!/usr/bin/bash
printf '%s %s\n' "${1##*/}" "$2" >> "$ASTRAL_SETUP_TEST/events"
[[ ${ASTRAL_FAIL_SYSTEM:-false} != true || $2 != --system ]]
MOCK
cat > "$runtime/bin/sudo" <<'MOCK'
#!/usr/bin/bash
exec "$@"
MOCK
chmod +x "$runtime/bin/"*
for mode in install update; do
  : > "$runtime/events"
  PATH="$runtime/bin:$PATH" /usr/bin/bash "$runtime/project/scripts/install-power.sh" "$mode"
  [[ $(cat "$runtime/events") == $'install-power.sh --user\ninstall-power.sh --system\n'"install-msi-ec.sh $mode" ]]
done
: > "$runtime/events"
if ASTRAL_FAIL_SYSTEM=true PATH="$runtime/bin:$PATH" /usr/bin/bash "$runtime/project/scripts/install-power.sh" update; then exit 1; fi
! rg -q install-msi-ec "$runtime/events"
printf 'POWER_SETUP_PASS\n'
