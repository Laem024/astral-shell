#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch launcher-test)
trap 'rm -rf -- "$runtime"' EXIT
trap 'printf "Launcher test failed at line %s\n" "$LINENO" >&2; cat "$runtime/state/astral-shell/astral-launcher/state.json" >&2' ERR
cp -r config/quickshell "$runtime/config"
sed 's|../../config/quickshell/|./|g' tests/applauncher/check.qml > "$runtime/config/check.qml"
mkdir -p "$runtime/run" "$runtime/home" "$runtime/bin" "$runtime/working dir" "$runtime/data/applications" "$runtime/system/applications" "$runtime/state/astral-shell/astral-launcher"
export XDG_CACHE_HOME=$runtime/cache XDG_CONFIG_HOME=$runtime/config-home
export ASTRAL_ORIGINAL_RUNTIME=${XDG_RUNTIME_DIR:-}
export ASTRAL_TEST_DIR=$runtime XDG_RUNTIME_DIR=$runtime/run HOME=$runtime/home XDG_STATE_HOME=$runtime/state
export XDG_DATA_HOME=$runtime/data XDG_DATA_DIRS=$runtime/system QT_QPA_PLATFORM=offscreen QT_QUICK_CONTROLS_STYLE=Basic
export PATH="$runtime/bin:$PATH"
printf 'invalid JSON' > "$runtime/state/astral-shell/astral-launcher/state.json"
for pair in 'native:Native' 'org.astral.Flatpak:Flatpak' 'appimage:AppImage' 'steam-123:Steam' 'duplicate:Native'; do
  id=${pair%%:*}; name=${pair#*:}
  printf '[Desktop Entry]\nType=Application\nName=%s Astral\nExec=true\n' "$name" > "$runtime/data/applications/$id.desktop"
done
printf '[Desktop Entry]\nType=Application\nName=Overridden\nExec=true\n' > "$runtime/system/applications/native.desktop"
for field in Hidden NoDisplay; do
  printf '[Desktop Entry]\nType=Application\nName=Hidden %s\nExec=true\n%s=true\n' "$field" "$field" > "$runtime/data/applications/$field.desktop"
done
cat > "$runtime/bin/gtk-launch" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$ASTRAL_TEST_DIR/graphical"
if [[ $1 == fail.desktop ]]; then
  printf 'Desktop entry unavailable.\n' >&2
  exit 1
fi
# Like gtk-launch, return while the application still holds the output streams.
(
  sleep 0.3
  printf 'Application diagnostic after gtk-launch exits.\n' >&2
  printf 'survived\n' > "$ASTRAL_TEST_DIR/graphical-survived"
) &
MOCK
cat > "$runtime/bin/astral-test-terminal" <<'MOCK'
#!/usr/bin/env bash
pwd > "$ASTRAL_TEST_DIR/cwd"
printf '%s\n' "$@" > "$ASTRAL_TEST_DIR/terminal"
MOCK
cat > "$runtime/bin/systemd-run" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$ASTRAL_TEST_DIR/requests"
directory=''
for option in --user --collect --quiet --service-type=exec --property=ExitType=cgroup --expand-environment=no; do
  found=false
  for arg in "$@"; do [[ $arg != "$option" ]] || found=true; done
  [[ $found == true ]] || exit 1
done
while [[ $1 != -- ]]; do
  case $1 in --working-directory=*) directory=${1#*=} ;; esac
  shift
done
shift
[[ -z $directory ]] || cd -- "$directory"
command -v -- "$1" >/dev/null || { printf 'request rejected: executable missing\n' >&2; exit 1; }
if [[ ${2:-} == fail.desktop ]]; then printf 'request rejected\n' >&2; exit 1; fi
# Simulate a service whose output is detached and whose children survive qs.
"$@" > "$ASTRAL_TEST_DIR/service-output" 2>&1 &
MOCK
chmod +x "$runtime/bin/systemd-run"
chmod +x "$runtime/bin/gtk-launch" "$runtime/bin/astral-test-terminal"
output=$(timeout 12 qs -p "$runtime/config/check.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *LAUNCHER_PASS* && $output != *LAUNCHER_FAIL* ]]
! [[ $output == *'TypeError'* || $output == *'ReferenceError'* || $output == *'Binding loop'* ]]
[[ $(cat "$runtime/cwd") == "$runtime/working dir" ]]
[[ ! -e "$runtime/working dir/INJECTED" ]]
cat > "$runtime/expected" <<'ARGS'
-e
printf
a b
$(touch INJECTED)
; touch INJECTED
'quoted'
ARGS
cmp "$runtime/expected" "$runtime/terminal"
[[ $(cat "$runtime/graphical") == native.desktop ]]
for ((attempt = 0; attempt < 30; attempt++)); do
  [[ ! -f $runtime/graphical-survived ]] || break
  sleep 0.05
done
[[ $(cat "$runtime/graphical-survived") == survived ]]
jq -e '.usage["terminal.desktop"].count==1 and (.favorites | index("native.desktop")!=null)' "$runtime/state/astral-shell/astral-launcher/state.json" >/dev/null
[[ $(stat -c %a "$runtime/state/astral-shell/astral-launcher/state.json") == 600 ]]
for check in persistence late-failure; do
  sed 's|../../config/quickshell/|./|g' "tests/applauncher/$check.qml" > "$runtime/config/$check.qml"
  output=$(timeout 5 qs -p "$runtime/config/$check.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
  printf '%s\n' "$output"
  [[ $output == *PASS* && $output != *LAUNCHER_FAIL* ]]
done
# A regular file in the state path produces a deterministic write failure.
printf 'blocked' > "$runtime/blocked"
[[ $(find "$runtime/state" -name state.json -type f | wc -l) == 1 ]]
sed 's|../../config/quickshell/|./|g' tests/applauncher/write-failure.qml > "$runtime/config/write-failure.qml"
output=$(XDG_STATE_HOME="$runtime/blocked" timeout 5 qs -p "$runtime/config/write-failure.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
[[ $output == *LAUNCHER_WRITE_PASS* && $output != *LAUNCHER_FAIL* ]]
bash tests/applauncher/run-session.sh
bash tests/applauncher/run-window.sh
# Run outside the private catalog/mocked manager environment.
PATH=${PATH#"$runtime/bin:"} XDG_RUNTIME_DIR=${ASTRAL_ORIGINAL_RUNTIME:-$XDG_RUNTIME_DIR} bash tests/applauncher/run-live.sh
printf 'LAUNCHER_SHELL_PASS\n'
