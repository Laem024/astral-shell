# Hyprland integration

`config/hyprland/` contains the Lua configuration, workspace grouping and optional idle configuration. `modules/autostart.lua` imports session variables into D-Bus/systemd, starts `astral-shell`, and starts the caffeine user unit. The root registry starts the bar, launcher, wallpaper, Polkit, native idle worker and closed session menu.

`Super+V` opens clipboard paste mode, `Super+Ctrl+V` opens delete mode, and `Super+Ctrl+Shift+V` clears history. `Super+Slash` opens shortcuts. `Alt+Tab` / `Alt+Shift+Tab` open and cycle workspace overview; releasing Alt confirms. The first press selects the active workspace. Wallpaper starts through the root registry; its carousel opens with `Super+Shift+W` (`astral-wallpaper carousel`) and its panel with `Super+Ctrl+W` (`astral-wallpaper toggle`). Ordinary application, window, workspace, media and resource-monitor bindings remain. `Super+Space` runs `astral-launcher`. `Super+Q` runs `astral-launcher close-active`, which closes overlays first and closes the active window only after every peer confirms inactivity or absence. Unknown state blocks the close. `Ctrl+Shift+Esc` opens `astral-monitor`, which is independent of Quickshell and checks logind `LockedHint` before opening (unknown state blocks opening).

`modules/workspaces.lua` queries `astral-shell workspace-count` on each key press with a one-second timeout. The installed command remembers the selected destination, including `--name`, and reads root `settings.json` without starting Quickshell or requiring the bar. Integers from 1 to 100 are accepted; failed or invalid queries fall back to ten. `astral-bar workspace-count` is a compatible alias. Special workspaces use the underlying normal workspace for block selection.

Astral Idle is the project’s sole idle implementation and handles automatic locking, display power and suspend through root `settings.json` idle preferences. Super+L locks through `astral-lock`; Super+Escape and Ctrl+Alt+Delete toggle `astral-session`. Caffeine inhibits idle and respects logind lid policy; it does not suppress the lid switch.

Install with `bash scripts/manage-configs.sh apply hyprland --dry-run` first, then remove `--dry-run` after review. Existing configuration is backed up. Never change the machine account or home directory to match the project name. See [Quickshell providers](quickshell.md), [power](energia.md), and [validation](pruebas.md).

`Super+R` requires `qalculate-gtk`, `Super+N` requires `mousepad`, and track/playback keys require `playerctl`. These packages are not installed automatically.

Updates retire `start-idle.sh` and `hypridle.conf` only when their contents exactly match the retired project versions. They are included in the normal full backup first (`--no-backup` skips it); `--dry-run` reports removals without writing. Customized copies remain in place with a review message. No external process is stopped or package uninstalled.
