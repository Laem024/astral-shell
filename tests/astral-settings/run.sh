#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
for file in config/hyprland/hyprland.lua config/hyprland/modules/astral-settings.lua config/hyprland/modules/keybindings.lua; do luac -p "$file"; done
lua tests/keybindings.lua
lua tests/astral-settings/loader.lua
if [[ -x /usr/lib/qt6/bin/qmltestrunner ]]; then
  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/astral-settings
fi
if command -v qs >/dev/null; then bash tests/astral-settings/runtime.sh; fi
printf 'ASTRAL_SETTINGS_PASS\n'
