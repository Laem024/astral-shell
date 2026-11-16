# Keyboard shortcuts panel

The active module lives in `config/quickshell/astral-shortcuts/` and starts through root `shortcuts.qml`. `Super+Slash` runs `astral-shortcuts`; the command accepts `toggle`, `close`, `close-active`, and `daemon`. Appearance follows shared root settings.

`data/ShortcutsData.qml` queries `hyprctl -j binds` directly with literal arguments. Qt JavaScript parses categories and key descriptions. Opening the panel and Hyprland's `configreloaded` event refresh the data. The UI retains category selection, search, modifier filters, keyboard navigation and loading/error states.

Run `bash tests/shortcuts/run.sh`, `lua tests/keybindings.lua`, and `bash scripts/test-quickshell.sh shortcuts`. Preview uses a sample binding library. Verify live binding changes after a Hyprland reload on CachyOS.
