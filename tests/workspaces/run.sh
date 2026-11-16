#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch workspaces)
trap 'rm -rf -- "$runtime"' EXIT
export XDG_CONFIG_HOME=$runtime/config
export HOME=$runtime/home XDG_CACHE_HOME=$runtime/cache
mkdir -p "$XDG_CONFIG_HOME/quickshell/astral-bar" "$runtime/bin" "$HOME"
bash scripts/manage-configs.sh apply quickshell --module astral-shortcuts --name selected > "$runtime/install.log"
export PATH="$HOME/.local/bin:$PATH"
[[ ! -e $XDG_CONFIG_HOME/quickshell/selected/astral-bar ]]
printf '{"workspaceCount":99}\n' > "$XDG_CONFIG_HOME/quickshell/astral-bar/settings.json"
[[ $(astral-shell workspace-count) == 10 ]]
lua tests/workspaces/grouping.lua config/hyprland/modules/workspaces.lua
# Failed and absent public query both fall back.
printf '#!/usr/bin/env bash\nexit 1\n' > "$runtime/bin/astral-shell"
chmod +x "$runtime/bin/astral-shell"
PATH="$runtime/bin:$PATH" lua -e 'local w=dofile("config/hyprland/modules/workspaces.lua"); assert(w.bar_count()==10)'
ln -s "$(command -v timeout)" "$runtime/bin/timeout"
rm "$runtime/bin/astral-shell"
PATH="$runtime/bin" "$(command -v lua)" -e 'local w=dofile("config/hyprland/modules/workspaces.lua"); assert(w.bar_count()==10)'
