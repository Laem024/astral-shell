#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if ! command -v qs >/dev/null; then printf 'SKIP: Quickshell is required.\n'; exit 0; fi
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch session-ui)
trap 'rm -rf -- "$runtime"' EXIT
cp -a config/quickshell "$runtime/config"
cp tests/quickshell/Headless*.qml "$runtime/config/"
printf 'HeadlessPanel 1.0 HeadlessPanel.qml\nHeadlessAnchors 1.0 HeadlessAnchors.qml\nHeadlessMargins 1.0 HeadlessMargins.qml\n' > "$runtime/config/qmldir"
sed -i -e 's/PanelWindow {/Headless.HeadlessPanel {/' -e '/WlrLayershell\./d' -e '/^import QtQuick$/a import "root:/" as Headless' "$runtime/config/astral-session/SessionMenu.qml"
mkdir -p "$runtime/bin" "$runtime/run"
chmod 700 "$runtime/run"
export ASTRAL_TEST_DIR=$runtime XDG_RUNTIME_DIR=$runtime/run XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
export PATH=$runtime/bin:$PATH
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
cat > "$runtime/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
if [[ -f $ASTRAL_TEST_DIR/locked ]]; then echo yes; else echo no; fi
MOCK
cat > "$runtime/bin/astral-lock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" >> "$ASTRAL_TEST_DIR/actions"
if [[ -e $ASTRAL_TEST_DIR/fail-${1:-} ]]; then
  printf 'simulated failure\n' >&2
  exit 1
fi
[[ ${1:-} != lock ]] || touch "$ASTRAL_TEST_DIR/locked"
MOCK
chmod 755 "$runtime/bin/"*
touch "$runtime/fail-poweroff"
sed 's|../../config/quickshell/|./|g' tests/session/check.qml > "$runtime/config/test.qml"
output=$(timeout 30 qs -p "$runtime/config/test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *SESSION_QML_PASS* && $output != *SESSION_FAIL* ]]
! rg -q 'ERROR|TypeError|ReferenceError|Binding loop|Failed to load configuration' <<< "$output"
[[ $(cat "$runtime/actions") == $'reboot\npoweroff\nlock' ]]
cat > "$runtime/config/preview-check.qml" <<'QML'
import QtQuick
import "astral-session" as Session
Session.SessionPreview {
  Timer { interval: 600; running: true; onTriggered: Qt.quit() }
}
QML
output=$(timeout 8 qs -p "$runtime/config/preview-check.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
! rg -q 'ERROR|TypeError|ReferenceError|Binding loop' <<< "$output"
[[ $(cat "$runtime/actions") == $'reboot\npoweroff\nlock' ]]
