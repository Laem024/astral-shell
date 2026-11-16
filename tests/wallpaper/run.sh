#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
for file in tests/wallpaper/*.sh tests/xdg-scratch.sh; do bash -n "$file"; done
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
export QT_NO_XDG_DESKTOP_PORTAL=1
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch wallpaper)
trap 'rm -rf -- "$runtime"' EXIT
export ASTRAL_TEST_DIR=$runtime HOME=$runtime/home XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache XDG_RUNTIME_DIR=$runtime/run
export XDG_CONFIG_HOME=$runtime/home/.config
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
mkdir -p "$runtime/run" "$HOME/Pictures/Wallpapers/"{light,dark,nested} "$runtime/bin" "$runtime/state/astral-shell/astral-wallpaper"
chmod 700 "$runtime/run"
cp -r config/quickshell "$runtime/config"
library=$HOME/Pictures/Wallpapers
for file in '00 first.png' light/light.png dark/dark.png still.webp still.bmp still.jpeg 'nested/spaces #?% $(touch INJECTED).png'; do
  ffmpeg -v error -nostdin -f lavfi -i 'color=c=navy:s=160x90' -frames:v 1 -threads 1 -y "$library/$file"
done
ffmpeg -v error -nostdin -f lavfi -i 'testsrc=size=160x90:rate=5' -t 2 -threads 1 -y "$library/motion.gif"
ffmpeg -v error -nostdin -f lavfi -i 'testsrc=size=160x90:rate=10' -t 3 -c:v libx264 -pix_fmt yuv420p -threads 1 -y "$library/motion.mp4"
ffmpeg -v error -nostdin -f lavfi -i 'testsrc=size=160x90:rate=10' -t 1 -c:v libvpx -threads 1 -y "$library/motion.webm"
ffmpeg -v error -nostdin -i "$library/motion.mp4" -c copy -y "$library/motion.mkv"
printf broken > "$library/broken.png"
printf ignored > "$library/ignored.txt"
printf 'invalid JSON' > "$runtime/state/astral-shell/astral-wallpaper/state.json"
cat > "$runtime/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$ASTRAL_TEST_DIR/curl-args"
while (( $# )); do
  case $1 in --config) config=$2; shift ;; --output) output=$2; shift ;; esac
  shift
done
[[ $config == - ]]
config=$(cat)
if [[ ${ASTRAL_NETWORK_CASE:-} == success ]]; then [[ $config == *apikey=TESTSECRET123* ]]; fi
if [[ -f $ASTRAL_TEST_DIR/network-fail ]]; then exit 7; fi
if [[ -f $ASTRAL_TEST_DIR/http-code ]]; then cat "$ASTRAL_TEST_DIR/http-code"; exit 0; fi
if [[ -f $ASTRAL_TEST_DIR/invalid-response ]]; then printf '{bad' > "$output"; printf 200; exit 0; fi
if [[ $config == *'/api/v1/search?'* ]]; then
  [[ $config == *purity=100* ]]
  cat > "$output" <<'JSON'
{"data":[{"id":"abc123","purity":"sfw","path":"https://w.wallhaven.cc/full/ab/wallhaven-abc123.png","resolution":"160x90","thumbs":{"large":"","small":""}},{"id":"skip","purity":"sketchy"}],"meta":{"current_page":2,"last_page":3}}
JSON
else
  if [[ -f $ASTRAL_TEST_DIR/interrupted ]]; then printf partial > "$output"; exit 18; fi
  if [[ -f $ASTRAL_TEST_DIR/damaged-download ]]; then printf damaged > "$output"; else cp "$HOME/Pictures/Wallpapers/00 first.png" "$output"; fi
fi
printf 200
MOCK
chmod +x "$runtime/bin/curl"
printf '#!/usr/bin/env bash\nexit 1\n' > "$runtime/bin/loginctl"
chmod 755 "$runtime/bin/loginctl"
export PATH="$runtime/bin:$PATH"
if [[ -f /usr/lib/qt6/qml/QtMultimedia/qmldir ]]; then
# Exercise the production renderer item in an offscreen Qt window.
sed 's|../../config/quickshell/|./|g' tests/wallpaper/check.qml > "$runtime/config/check.qml"
output=$(timeout 30 qs -p "$runtime/config/check.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_QML_PASS* && $output != *WALLPAPER_FAIL* ]]
! rg -q 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' <<< "$output"
[[ ! -e INJECTED ]]
[[ $(stat -c %a "$runtime/state/astral-shell/astral-wallpaper/state.json") == 600 ]]
jq -e '.version == 1 and (.selections.dark.monitors | has("B"))' "$runtime/state/astral-shell/astral-wallpaper/state.json" >/dev/null
sed 's|../../config/quickshell/|./|g' tests/wallpaper/media.qml > "$runtime/config/media.qml"
output=$(timeout 20 qs -p "$runtime/config/media.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_MEDIA_PASS* && $output != *WALLPAPER_FAIL* ]]
! rg -q 'TypeError|ReferenceError|Binding loop' <<< "$output"
sed 's|../../config/quickshell/|./|g' tests/wallpaper/restore.qml > "$runtime/config/restore.qml"
output=$(timeout 5 qs -p "$runtime/config/restore.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_RESTORE_PASS* && $output != *WALLPAPER_FAIL* ]]
sed 's|../../config/quickshell/|./|g' tests/wallpaper/selector.qml > "$runtime/config/selector.qml"
output=$(timeout 20 qs -p "$runtime/config/selector.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_SELECTOR_PASS* && $output != *WALLPAPER_FAIL* ]]
! rg -q 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' <<< "$output"
# Exercise the real dialog in both themes and at both configured scales.
for test_theme in dark light; do
  for test_scale in 1 1.5; do
    output=$(ASTRAL_TEST_THEME=$test_theme ASTRAL_TEST_SCALE=$test_scale ASTRAL_TEST_WIDTH=800 ASTRAL_TEST_HEIGHT=600 \
      ASTRAL_WALLPAPER_CAPTURE="${ASTRAL_CAPTURE_DIR:+$ASTRAL_CAPTURE_DIR/$test_theme-$test_scale.png}" \
      XDG_STATE_HOME="$runtime/selector-$test_theme-$test_scale" timeout 20 qs -p "$runtime/config/selector.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
    [[ $output == *WALLPAPER_SELECTOR_PASS* && $output != *WALLPAPER_FAIL* ]]
    ! rg -q 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' <<< "$output"
    printf 'WALLPAPER_LAYOUT_PASS (%s, scale %s, 800x600)\n' "$test_theme" "$test_scale"
  done
done
timeout 20 bash tests/wallpaper/reload.sh "$runtime/config"
sed 's|../../config/quickshell/|./|g' tests/wallpaper/carousel.qml > "$runtime/config/carousel.qml"
output=$(XDG_STATE_HOME="$runtime/carousel-state" timeout 20 qs -p "$runtime/config/carousel.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_CAROUSEL_PASS* && $output != *WALLPAPER_FAIL* ]]
! rg -q 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' <<< "$output"
else
  printf 'SKIP: renderer, media and selector checks require the QtMultimedia QML module.\n'
fi
cp "$library/00 first.png" "$library/"$'tab\tand\nnewline.png'
cp "$library/00 first.png" "$library/missing-test.png"
sed 's|../../config/quickshell/|./|g' tests/wallpaper/operations.qml > "$runtime/config/operations.qml"
output=$(XDG_STATE_HOME="$runtime/operations-state" timeout 20 qs -p "$runtime/config/operations.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_OPERATIONS_PASS* && $output != *WALLPAPER_FAIL* ]]
mkdir -p "$runtime/service-state/astral-shell/astral-wallpaper"
printf invalid > "$runtime/service-state/astral-shell/astral-wallpaper/state.json"
sed 's|../../config/quickshell/|./|g' tests/wallpaper/service.qml > "$runtime/config/service.qml"
output=$(XDG_STATE_HOME="$runtime/service-state" timeout 15 qs -p "$runtime/config/service.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *WALLPAPER_SERVICE_PASS* && $output != *WALLPAPER_FAIL* ]]
sed 's|../../config/quickshell/|./|g' tests/wallpaper/persistence.qml > "$runtime/config/persistence.qml"
output=$(XDG_STATE_HOME="$runtime/service-state" timeout 10 qs -p "$runtime/config/persistence.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
[[ $output == *WALLPAPER_PERSISTENCE_PASS* ]]
printf '%s\n' "$output"
[[ $(stat -c %a "$runtime/service-state/astral-shell/astral-wallpaper/state.json") == 600 ]]
[[ ! -e INJECTED ]]
# HTTP and authentication exercise the same QML service as the selector.
sed 's|../../config/quickshell/|./|g' tests/wallpaper/network.qml > "$runtime/config/network.qml"
for scenario in success 401 403 429 500 offline invalid interrupted damaged; do
  rm -f "$runtime/http-code" "$runtime/network-fail" "$runtime/invalid-response" "$runtime/interrupted" "$runtime/damaged-download"
  case $scenario in
    401|403|429|500) printf '%s' "$scenario" > "$runtime/http-code" ;;
    offline) touch "$runtime/network-fail" ;;
    invalid) touch "$runtime/invalid-response" ;;
    interrupted) touch "$runtime/interrupted" ;;
    damaged) touch "$runtime/damaged-download" ;;
  esac
  output=$(ASTRAL_NETWORK_CASE=$scenario timeout 15 qs -p "$runtime/config/network.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
  [[ $output == *WALLPAPER_NETWORK_PASS* && $output != *WALLPAPER_FAIL* ]]
  printf '%s\n' "$output"
done
! rg -q 'TESTSECRET123|apikey' "$runtime/curl-args"
[[ $(stat -c %a "$runtime/state/astral-shell/astral-wallpaper/api-key") == 600 ]]
[[ $(stat -c %a "$runtime/state/astral-shell/astral-wallpaper") == 700 ]]
[[ -z $(find "$runtime/cache" "$library" -name '.request-*' -print) ]]
# Installation is covered by the shared suite, including wallpaper replacements.
bash tests/wallpaper/session.sh
printf 'WALLPAPER_PASS\n'
