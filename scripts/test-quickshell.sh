#!/usr/bin/env bash
set -euo pipefail
mode=${1:-all}
if (( $# > 1 )) || [[ $mode != all && $mode != bar && $mode != wallpaper && $mode != launcher && $mode != polkit && $mode != lock && $mode != session && $mode != clipboard && $mode != overview && $mode != shortcuts ]]; then
  printf 'Usage: bash scripts/test-quickshell.sh [all|bar|wallpaper|launcher|polkit|lock|session|clipboard|overview|shortcuts]\n' >&2
  exit 2
fi
command -v qs >/dev/null || { printf 'Quickshell (qs) is required for graphical preview.\n' >&2; exit 1; }
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../config/quickshell" && pwd)
preview_root=${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/astral-shell/previews
[[ $preview_root == /* ]] || { printf 'XDG_CACHE_HOME must be absolute.\n' >&2; exit 1; }
mkdir -p -m 700 -- "$preview_root"
preview=$(mktemp -d "$preview_root/preview-XXXXXXXX")
process=''
cleanup() {
  local path
  for path in clipboard overview shortcuts; do qs kill -p "$preview/config/quickshell/$path-preview.qml" >/dev/null 2>&1 || true; done
  # Every path is inside our unique copy; installed/repository instances are untouched.
  for path in "$preview/config/quickshell/shell.qml" "$preview/config/quickshell/bar.qml" "$preview/config/quickshell/bar-preview.qml" "$preview/config/quickshell/recorder.qml" "$preview/config/quickshell/launcher-preview.qml" "$preview/config/quickshell/wallpaper-preview.qml" "$preview/config/quickshell/polkit-preview.qml" "$preview/config/quickshell/lock-preview.qml" "$preview/config/quickshell/session-preview.qml"; do
    qs kill -p "$path" >/dev/null 2>&1 || true
  done
  [[ -z $process ]] || wait "$process" 2>/dev/null || true
  rm -rf -- "$preview"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p -- "$preview/config" "$preview/cache" "$preview/state" "$preview/data" "$preview/runtime" "$preview/bin"
chmod 700 "$preview/runtime"
cp -a -- "$base" "$preview/config/quickshell"
if [[ $mode == wallpaper || $mode == all ]]; then
  if [[ ! -f /usr/lib/qt6/qml/QtMultimedia/qmldir ]]; then printf 'Wallpaper preview requires the QtMultimedia QML module.\n' >&2; exit 1; fi
  command -v ffmpeg >/dev/null || { printf 'Wallpaper preview requires ffmpeg.\n' >&2; exit 1; }
  mkdir -p "$preview/library/"{light,dark} "$preview/state/astral-shell/astral-wallpaper"
  for theme in light dark; do
    color=navy; [[ $theme != light ]] || color=ivory
    ffmpeg -v error -nostdin -f lavfi -i "color=c=$color:s=1280x720" -frames:v 1 -threads 1 -y "$preview/library/$theme/sample.png"
  done
  jq -n --arg folder "$preview/library" '{version:1,folder:$folder,layout:"Mirror",fade:500,rotation:false,minutes:30,random:true,selections:{light:{common:"",monitors:{}},dark:{common:"",monitors:{}}}}' > "$preview/state/astral-shell/astral-wallpaper/state.json"
  chmod 600 "$preview/state/astral-shell/astral-wallpaper/state.json"
  printf 'import "astral-wallpaper" as Wallpaper\nWallpaper.WallpaperPreview {}\n' > "$preview/config/quickshell/wallpaper-preview.qml"
  jq '(.modules[] | select(.id=="astral-wallpaper") | .path)="wallpaper-preview.qml"' "$base/settings.json" > "$preview/config/quickshell/settings.json"
fi
printf 'import "astral-bar" as Bar\nBar.BarPreview {}\n' > "$preview/config/quickshell/bar-preview.qml"
if [[ $mode == all ]]; then
  jq '(.modules[] | select(.id=="astral-bar") | .path)="bar-preview.qml"' "$preview/config/quickshell/settings.json" > "$preview/settings.json"
  mv -- "$preview/settings.json" "$preview/config/quickshell/settings.json"
fi
printf 'import "astral-launcher" as Launcher\nLauncher.LauncherPreview {}\n' > "$preview/config/quickshell/launcher-preview.qml"
printf 'import "astral-polkit" as Polkit\nPolkit.PolkitPreview {}\n' > "$preview/config/quickshell/polkit-preview.qml"
printf 'import "astral-lock" as Lock\nLock.LockPreview {}\n' > "$preview/config/quickshell/lock-preview.qml"
printf 'import "astral-session" as Session\nSession.SessionPreview {}\n' > "$preview/config/quickshell/session-preview.qml"
for panel in clipboard overview shortcuts; do
  printf 'import "astral-%s" as Module\nModule.%sPreview {}\n' "$panel" "${panel^}" > "$preview/config/quickshell/$panel-preview.qml"
done
# Preview instances never run native idle policies or the real session menu.
jq '.providers |= with_entries(.value=[]) | (.idle.enabled)=false | .modules |= map(if .id=="astral-clipboard" then .path="clipboard-preview.qml" elif .id=="astral-overview" then .path="overview-preview.qml" elif .id=="astral-shortcuts" then .path="shortcuts-preview.qml" elif .id=="astral-idle" then .enabled=false elif .id=="astral-session" then .path="session-preview.qml" else . end)' "$preview/config/quickshell/settings.json" > "$preview/settings.json"
mv -- "$preview/settings.json" "$preview/config/quickshell/settings.json"
if [[ $mode == all ]]; then
  jq '(.modules[] | select(.id=="astral-launcher") | .path)="launcher-preview.qml" | (.modules[] | select(.id=="astral-polkit") | .path)="polkit-preview.qml" | (.modules[] | select(.id=="astral-lock")) |= (.path="lock-preview.qml" | .autostart=true)' "$preview/config/quickshell/settings.json" > "$preview/settings.json"
  mv -- "$preview/settings.json" "$preview/config/quickshell/settings.json"
fi
# Keep compositor/audio sockets reachable while isolating the preview's files.
original_runtime=${XDG_RUNTIME_DIR:-}
if [[ -n ${WAYLAND_DISPLAY:-} && $WAYLAND_DISPLAY != /* ]]; then export WAYLAND_DISPLAY=$original_runtime/$WAYLAND_DISPLAY; fi
export PIPEWIRE_RUNTIME_DIR=${PIPEWIRE_RUNTIME_DIR:-$original_runtime}
export PULSE_SERVER=${PULSE_SERVER:-unix:$original_runtime/pulse/native}
export XDG_DATA_HOME=$preview/data
export XDG_CONFIG_HOME=$preview/config XDG_CACHE_HOME=$preview/cache XDG_STATE_HOME=$preview/state XDG_RUNTIME_DIR=$preview/runtime
# Preview launcher requests always target the simulated application library.
printf '#!/usr/bin/env bash\nexec qs -p %q --no-duplicate "$@"\n' "$preview/config/quickshell/shell.qml" > "$preview/bin/astral-shell"
printf '#!/usr/bin/env bash\nexec bash %q %q "$@"\n' "$preview/config/quickshell/dispatch.sh" "$preview/config/quickshell/bar.qml" > "$preview/bin/astral-bar"
printf '#!/usr/bin/env bash\ncase ${1:-toggle} in close|close-active) exit 0 ;; esac\nexec qs -p %q --no-duplicate\n' "$preview/config/quickshell/launcher-preview.qml" > "$preview/bin/astral-launcher"
chmod 755 "$preview/bin/astral-launcher"
chmod 755 "$preview/bin/astral-shell" "$preview/bin/astral-bar"
export PATH=$preview/bin:$PATH
entry=$preview/config/quickshell/shell.qml
[[ $mode != wallpaper ]] || entry=$preview/config/quickshell/wallpaper-preview.qml
[[ $mode != launcher ]] || entry=$preview/config/quickshell/launcher-preview.qml
[[ $mode != polkit ]] || entry=$preview/config/quickshell/polkit-preview.qml
[[ $mode != lock ]] || entry=$preview/config/quickshell/lock-preview.qml
for panel in clipboard overview shortcuts; do [[ $mode != "$panel" ]] || entry=$preview/config/quickshell/$panel-preview.qml; done
[[ $mode != session ]] || entry=$preview/config/quickshell/session-preview.qml
[[ $mode != bar ]] || entry=$preview/config/quickshell/bar-preview.qml
printf 'Previewing %s. Close with Ctrl+C.\n' "$mode"
qs -p "$entry" --no-duplicate &
process=$!
wait "$process"
