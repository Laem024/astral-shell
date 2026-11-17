# Astral Shell

A personal CachyOS environment built around Hyprland and Quickshell, with configuration installers, an SDDM theme, and a separate Kitty/btop resource monitor.

## Current migration stage

`config/quickshell/` contains the new orchestrator, `astral-bar`, `astral-launcher`, `astral-wallpaper`, `astral-polkit`, `astral-lock`, `astral-session`, `astral-clipboard`, `astral-overview`, and `astral-shortcuts`. The bar preserves its four positions, multiple monitors, panels, tray, notifications, weather, network, Bluetooth, VPN, media, audio, brightness, and capture controls. The redesigned control center has seven English categories, an editable panoramic banner, and a framed account portrait. `astral-bar/panel/ProfileHeader.qml`, `CategoryGlyph.qml`, and `PageIntro.qml` provide its shared presentation. Its backend uses QML, Quickshell APIs, and JavaScript executed by Qt. Existing command-line tools receive separate arguments; no new package or language is required.

The visual direction is **Astral depurado**: one bar surface, compact Sound controls,
Connections tabs, a search-and-list launcher, horizontal session actions and a
left-aligned SDDM login with a responsive centered layout. See the
[visual compositions](docs/design-system.md#astral-depurado-composition).

`config/quickshell-old/` is reference material. The new installer does not copy or start it. Clipboard, overview, and shortcuts start through the registry and use shared QML coordination. The lock and session menu use shared argument-array providers; empty providers hide actions. Existing destination-only files and old public commands are retained, so stop any old daemons before switching configurations.

## Try and validate

Run as a regular user. These commands do not install dependencies or replace active dotfiles:

```bash
bash tests/quickshell/run.sh
bash tests/wallpaper/run.sh
bash tests/applauncher/run.sh
bash tests/lock/run.sh
bash tests/session/run.sh
bash tests/clipboard/run.sh
bash tests/overview/run.sh
bash tests/shortcuts/run.sh
bash scripts/test-quickshell.sh bar
bash scripts/test-quickshell.sh wallpaper
bash scripts/test-quickshell.sh launcher
bash scripts/test-quickshell.sh lock
bash scripts/test-quickshell.sh session
bash scripts/test-quickshell.sh clipboard
bash scripts/test-quickshell.sh overview
bash scripts/test-quickshell.sh shortcuts
bash scripts/test-quickshell.sh all
bash scripts/manage-configs.sh apply quickshell --dry-run
```

Preview requires `qs` in a Wayland session. It makes a unique configuration copy, isolates XDG runtime/cache/state, and cleans up only instances launched from that copy. Screenshots and recordings still go to your Pictures and Videos directories.

The automated entry point checks shell syntax, disposable installations, configuration validation, registry filtering, safe brightness mapping, and capture geometry. With `qs`, it also runs mocked backend integration checks. Real display, audio, Bluetooth, and compositor behavior must be checked on CachyOS; see [validation](docs/pruebas.md).

Focus's **Force close** resolves the selected window's address against Hyprland's client list, so returning focus from the menu cannot redirect or cancel the kill. Address and PID validation lives in `config/quickshell/astral-bar/data/WindowLogic.js`, with regression checks in `tests/quickshell/tst_logic.qml`.

## Install

```bash
bash scripts/manage-configs.sh apply quickshell
bash scripts/manage-configs.sh apply quickshell --module astral-bar
bash scripts/manage-configs.sh apply quickshell --module astral-wallpaper
bash scripts/manage-configs.sh apply quickshell --module astral-bar --name personal
bash scripts/manage-configs.sh apply quickshell --module astral-bar --source '/path with spaces/custom-bar'
```

An external source can be a directory with `shell.qml`, or a QML file. It does not need `settings.json` or `session.sh`. Partial installation includes the root dependencies once. The destination is `$XDG_CONFIG_HOME/quickshell/`, or `~/.config/quickshell/`, with `--name` selecting a subdirectory.

The installer backs up the existing destination in `.backups/` before changes. It preserves preferences and separates old common preferences from bar preferences. `--no-backup` explicitly skips backups. Review the dry run first. To roll back, stop the new instances, restore the selected backup, and restore command backups in `~/.local/bin/` when applicable.

The ten public commands are `astral-shell`, `astral-bar`, `astral-launcher`, `astral-wallpaper`, `astral-polkit`, `astral-lock`, `astral-session`, `astral-clipboard`, `astral-overview`, and `astral-shortcuts`. The bar supports `start`, `daemon`, and `close-panels`. `astral-shell workspace-count` reads the installed root settings without starting Quickshell; `astral-bar workspace-count` aliases that query. Commands remember the chosen destination.

For the complete machine setup, `./install.sh` and `./install.sh update` run the existing package, configuration, SDDM, and power installers. They request system privileges where required. This migration does not automatically install dependencies during validation or preview. See [installation](docs/instalacion.md).

Clipboard preferences (`historySize`, `maxImageBytes`, `enterAction`, and `pasteShortcut`), overview `previews`, and the shared `workspaceCount` belong to root `settings.json`. Installation migrates the old bar workspace count and module preferences without replacing root preferences. Clipboard history stays at `$XDG_STATE_HOME/astral-shell/astral-clipboard/history.json` (version 1), with private image files in `images/`.

`astral-clipboard/`, `astral-overview/`, and `astral-shortcuts/` contain the active UI and Qt JavaScript services. Root `clipboard.qml`, `overview.qml`, and `shortcuts.qml` are stock entries; their `*-control.qml` files use `common/PanelControl.qml`. Tests in `tests/panels/` cover startup, simulated previews, and controller concurrency. Preview panels use sample data in ordinary windows and never capture or paste clipboard contents or dispatch window actions.

## Configuration and locations

| Location | Purpose |
| --- | --- |
| `config/quickshell/shell.qml` | Registry-driven module orchestration |
| `config/quickshell/bar.qml`, `recorder.qml`, `wallpaper.qml` | Root entries that keep module/worker shared imports inside Quickshell’s configuration boundary |
| `config/quickshell/astral-lock/` | PAM lock, native idle notifications, logind sleep guard and safe preview |
| `config/quickshell/astral-session/` | Session menu and action confirmation |
| `config/quickshell/lock.qml`, `idle.qml`, `session.qml` | Root entries for lock, idle and session modules |
| `config/quickshell/settings.json` | Shared workspace count, idle, colors, mode, scale, animation, clock, apps, providers, registry |
| `config/quickshell/common/` | One settings loader/validator, theme, paths, argument runner, privacy, popup dismissal, caffeine worker |
| `config/quickshell/astral-bar/settings.json` | Position, margins, visibility, replacements, weather and logo |
| `config/quickshell/astral-bar/modules/` | Visual slots and their stock `Default*.qml` implementations |
| `config/quickshell/astral-bar/components/` | Reusable visuals, animated edge marker (`HoverIndex.qml`) and workspace hover outline (`NeonOutline.qml`) |
| `config/quickshell/astral-bar/panel/` | Panels, tray menu, and notification presentation |
| `config/quickshell/astral-bar/data/` | Native services and Qt JavaScript logic |
| `config/quickshell/astral-bar/display/` | Native window capture and independent recording entry |
| `config/quickshell/astral-polkit/` | Native authentication service, private dialog and safe preview |
| `config/quickshell/astral-launcher/` | Compact application list, favorites, history and atomic state |
| `config/quickshell/astral-wallpaper/` | Selector, carousel and reusable coordinated renderer |
| `config/quickshell/astral-wallpaper/library/` | FileView state and NUL-delimited library scan |
| `config/quickshell/astral-wallpaper/thumbnails/` | Bounded metadata-keyed ffmpeg thumbnail queue |
| `config/quickshell/astral-wallpaper/wallhaven/` | Authenticated Wallhaven searches and filters, response validation and atomic downloads |
| `config/quickshell/wallpaper-control.qml` | Single-start readiness and IPC command coordination |
| `config/quickshell/dispatch.sh` | Public bar, launcher and wallpaper command dispatch |
| `config/hyprland/` | Hyprland configuration and workspace grouping |
| `config/monitor/` | Separate `astral-monitor` resource workspace |
| `config/sddm/` | SDDM theme |
| `scripts/` | Installers, preview, configuration management |
| `system/power/` | Privileged charge administration and caffeine unit |
| `tests/wallpaper/` | Wallpaper services, renderer, network and command checks |
| `tests/xdg-scratch.sh`, `tests/scratch/run.sh` | Private XDG scratch and D-Bus helper; isolation and cleanup checks |
| `tests/notifications/` | Notification UI, independent file opens, fallback and user-service lifetime checks |
| `tests/quickshell/` | Migration checks and mocked integration fixtures |

The launcher starts hidden with `astral-shell`. Use `astral-launcher` or `Super+Space` to toggle it, and `Super+Q` to cancel active authentication, then close wallpaper, bar panels or launcher before the active application. Root settings provide the terminal and launcher provider; user systemd services keep launched applications alive across shell reloads. Favorites and history use private version 1 JSON under `$XDG_STATE_HOME/astral-shell/astral-launcher/`. See [launcher commands and behavior](docs/launcher.md).

Wallpaper starts with `astral-shell` and keeps its selector and carousel closed. Use `astral-wallpaper [toggle|carousel|daemon|close|close-active] [monitor]`, or `astral-wallpaper DP-1` to open the selector on a monitor. `close` and `close-active` never start the background service. The selector shares the shell's Light/Dark theme, uses `~/Pictures/Wallpapers` by default, and supports images, GIFs, video, Mirror, Span and Per monitor layouts. QtMultimedia's QML module, ffmpeg (including ffprobe), curl, find and flock are prerequisites; no dependency is installed automatically.

State and the optional API key stay in `$XDG_STATE_HOME/astral-shell/astral-wallpaper/` (default `~/.local/state/`); thumbnails use `$XDG_CACHE_HOME/astral-shell/astral-wallpaper/`. Test scratch, installer staging and previews also use private Astral XDG directories. A wallpaper preview uses generated samples in ordinary windows and does not replace the compositor background. Renderer and selector checks report a skip when QtMultimedia is unavailable; real multi-monitor rendering still requires manual CachyOS validation.

Settings reload after validated edits; invalid or missing files retain the last valid values. Initial errors use bundled defaults. Optional external modules need only their entry QML. See [Quickshell configuration and replacement contracts](docs/quickshell.md).

Runtime files use `$XDG_RUNTIME_DIR/astral-shell`, weather uses `$XDG_CACHE_HOME/astral-shell/astral-bar`, and preferences/profile data use `$XDG_STATE_HOME/astral-shell` (with standard home-directory fallbacks for cache and state). Capture output uses the XDG Pictures/Screenshots and Videos/ScreenRecordings folders.

## Documentation

- [Quickshell and external modules](docs/quickshell.md)
- [Bar and panels](docs/barra-y-panel.md)
- [Capture and display](docs/captura-y-pantalla.md)
- [Power and session actions](docs/energia.md)
- [Validation](docs/pruebas.md)
- [Hyprland](docs/hyprland.md), [installation](docs/instalacion.md), [resource monitor](docs/monitor.md), [SDDM](docs/sddm.md), and [MSI driver setup](docs/msi-ec.md)

Never rename the machine account or home directory when changing project names. Never commit credentials or machine-specific secrets.

Hyprland shortcut registration checks live in `tests/keybindings.lua`; see [Hyprland integration](docs/hyprland.md) for bindings and optional application dependencies.

Astral Polkit starts automatically with the shell. Use `astral-polkit [daemon|status|cancel|restart]` to manage it, and `bash scripts/test-quickshell.sh polkit` for a demonstration that registers no agent. See [Polkit behavior and validation](docs/polkit.md).

Astral Idle owns automatic locking, display power and suspend; preferences live in `config/quickshell/settings.json`. Hypridle is no longer a project dependency. Applying Hyprland removes only exact copies of the retired project helper/config after the usual backup; customized copies require manual review. Dry runs and `--no-backup` are respected. External idle processes and installed packages are left to the user.
