#!/usr/bin/env bash
# Use the disposable configuration and environment prepared by run.sh.
set -euo pipefail
config=${1:?Temporary configuration directory required}
log=$ASTRAL_TEST_DIR/reload-output
project=$ASTRAL_TEST_DIR/reload-project
installed=$ASTRAL_TEST_DIR/reload-home/quickshell
mkdir -p "$project/scripts/configs" "$project/config/quickshell/astral-wallpaper" "${installed%/*}"
cp -rL "$config" "$installed"
cp scripts/manage-configs.sh "$project/scripts/"
cp scripts/cleanup-install.sh "$project/scripts/"
cp scripts/configs/{common,quickshell}.sh "$project/scripts/configs/"
cp "$config/astral-wallpaper/"{WallpaperContent,WallpaperComboBox}.qml "$project/config/quickshell/astral-wallpaper/"
cp -a "$config/common" "$project/config/quickshell/common"
for name in shell.qml bar.qml recorder.qml wallpaper.qml wallpaper-control.qml settings.json dispatch.sh; do cp "$config/$name" "$project/config/quickshell/$name"; done
cp "$config/astral-wallpaper/shell.qml" "$project/config/quickshell/astral-wallpaper/shell.qml"
# Keep traversal order deterministic: the importer is encountered first, just
# as it was in the installed configuration that failed to reload.
rm "$installed/astral-wallpaper/WallpaperComboBox.qml"
# Start the same process with a previous selector, then install the new source.
cat > "$installed/astral-wallpaper/WallpaperContent.qml" <<'QML'
import QtQuick.Controls
Pane {
  required property var service
  required property var tokens
  property string tab: "Legacy"
}
QML
sed 's|../../config/quickshell/|./|g' tests/wallpaper/reload.qml > "$installed/reload.qml"
qs -p "$installed/reload.qml" --no-color > "$log" 2>&1 &
shell_pid=$!
trap 'kill "$shell_pid" 2>/dev/null || true' EXIT
for ((attempt = 0; attempt < 100; attempt++)); do
  if rg -q WALLPAPER_RELOAD_READY "$log"; then break; fi
  kill -0 "$shell_pid" 2>/dev/null || { cat "$log"; exit 1; }
  sleep 0.05
done
rg -q WALLPAPER_RELOAD_READY "$log" || { cat "$log"; exit 1; }
# Slow each copy enough to let the file watcher observe installation order.
mkdir -p "$ASTRAL_TEST_DIR/reload-bin"
cat > "$ASTRAL_TEST_DIR/reload-bin/cp" <<'MOCK'
#!/usr/bin/env bash
/usr/bin/cp "$@"
case ${!#} in
  */quickshell/astral-wallpaper/WallpaperContent.qml|*/quickshell/astral-wallpaper/WallpaperComboBox.qml) sleep 0.3 ;;
esac
MOCK
chmod +x "$ASTRAL_TEST_DIR/reload-bin/cp"
PATH="$ASTRAL_TEST_DIR/reload-bin:$PATH" XDG_CONFIG_HOME="${installed%/*}" \
  bash "$project/scripts/manage-configs.sh" apply quickshell --module astral-wallpaper > "$ASTRAL_TEST_DIR/reload-install-output" 2>&1 \
  || { cat "$ASTRAL_TEST_DIR/reload-install-output" "$log"; exit 1; }
wait "$shell_pid" || { cat "$log"; exit 1; }
cat "$log"
rg -q WALLPAPER_RELOAD_PASS "$log"
! rg -q 'WALLPAPER_FAIL|TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' "$log"
