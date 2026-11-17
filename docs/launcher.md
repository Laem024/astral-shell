# Application launcher

`config/quickshell/astral-launcher/` contains the active QML launcher. The root
`launcher.qml` entry imports the shared theme, settings, logind privacy and popup
policies from `common/`. The module starts hidden with `astral-shell`.

## Commands and keyboard

Use `astral-launcher [toggle [monitor]|monitor|daemon|close|close-active]`.
No arguments toggles on the focused monitor; `astral-launcher DP-1` selects a
monitor. `Super+Space` toggles the launcher. `Super+Q` asks Polkit authentication, wallpaper, bar panels,
then launcher to consume the close before closing the active application.
Unknown logind or overlay state prevents closing an application. Closing never
starts a missing module or calls pending modules.

Search ignores case and accents. Arrow keys navigate, Enter launches, Escape
closes and Ctrl+F toggles the selected favorite. Discover, Favorites, Frequent
and All are category tabs above a scrolling results list. Each row shows an icon,
name, available description and favorite button. Up/Down navigate rows, Left/Right
move to the previous/next result, and Up from the first row returns to search.
The window is capped at 620 × 560 logical pixels and shrinks to the screen.
Disconnecting the selected monitor or locking the session hides the launcher.

## Settings and storage

Root `settings.json` owns appearance, `applications.terminal`, providers and the
module registry. The bar defaults to `["astral-launcher"]`; external argument
arrays remain supported and receive the monitor as their last argument.
External launcher replacements need only a QML entry and should implement target
`launcher` with `state`, `isOpen`, `toggle`, `close` and `closeActive`. Readiness
uses `loading`/`ready`, toggle uses `ok`/`blocked`, and closeActive uses
`closed`/`inactive`/`blocked`. Unknown replies fail closed.

Favorites and usage retain version 1 JSON at
`$XDG_STATE_HOME/astral-shell/astral-launcher/state.json`, falling back to
`~/.local/state`. QML FileView writes atomically; directories are private and
state files use mode 600. Invalid or unavailable storage shows a warning and
keeps changes in memory. Startup serialization uses a private flock under
`$XDG_RUNTIME_DIR/astral-shell/`.

## Application lifetime

`common/ApplicationLaunch.qml` submits argument arrays to user systemd services
with `Type=exec`, `ExitType=cgroup` and environment expansion disabled. Graphical
entries use gtk-launch; terminal entries use the configured terminal, `-e`,
Quickshell's parsed command and the entry's working directory. Only accepted
requests update history. Acceptance confirms executable startup; later application
errors stay in the service journal. Services survive launcher closure and
Quickshell reloads. A systemd user manager, gtk-launch and the configured terminal
must already be available; installation adds no dependencies.

## Validation and preview

Run `bash tests/applauncher/run.sh` for logic, catalog, corrupt state, persistence,
write failures, literal launch arguments, IPC, privacy and startup checks.
`bash scripts/test-quickshell.sh launcher` opens an isolated ordinary window with
fictional applications and an in-memory service: activation cannot launch real
programs. `all` includes this preview. Verify real Hyprland focus, monitor removal,
and animations on CachyOS before installing active dotfiles.

Left/Right switch category tabs (including from search); Up/Down select application rows. Favorites use a vector star with a gold fill when pinned.
