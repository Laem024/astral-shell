# Quickshell migration

The orchestrator, bar, launcher, wallpaper, Polkit, lock, session menu, clipboard, overview and shortcuts are active in `config/quickshell/`. `config/quickshell-old/` remains reference only.

## Shared configuration

Edit the installed root `settings.json` for `workspaceCount`, `clipboard`, `overview`, `profile`, `lockScreen`, `idle`, `colors`, `mode`, `scale`, `animations`, `clockFormat`, `applications`, `providers`, and `modules`. `common/SettingsStore.qml` loads files through FileView and validates them through `common/Validation.js`. A failed reload leaves the last valid configuration active and reports an error. Bundled defaults cover the first load if the file is missing or invalid. The bar's settings adapter combines common values with its local preferences; configuration loading and theme implementation live only at the root.

The module registry is an array:

```json
[
  {"id":"astral-bar", "path":"bar.qml", "enabled":true, "autostart":true},
  {"id":"astral-wallpaper", "path":"wallpaper.qml", "enabled":true, "autostart":true},
  {"id":"personal", "path":"/home/me/Custom Shell/main.qml", "enabled":true, "autostart":false}
]
```

IDs must be unique. Paths are absolute or relative to the root and may contain spaces. A directory resolves to `shell.qml`; a `.qml` path is used directly. A module requires only that entry point, and can optionally import Astral's common theme. `enabled && autostart` controls startup. The orchestrator maintains independent `qs --no-duplicate -p PATH` processes from the registry. Removal, disabling, or a path change stops the child it owns; unchanged entries remain intact. A duplicate that was already running is not owned and is not stopped. A failed entry is reported without preventing other entries from starting. Failed entries are retried on the next orchestrator launch or after removing and re-adding their registry entry.

The built-in bar starts through root `bar.qml`, which statically imports `astral-bar/BarRoot.qml`. The recorder likewise starts through root `recorder.qml`. Quickshell blocks relative imports that escape its entry directory, so these root entries keep shared dependencies within the configuration root. Use `qs -p config/quickshell/bar.qml` for a direct bar launch.

## Bar preferences

`astral-bar/settings.json` owns `position` (`top`, `bottom`, `left`, `right`), `margin`, `workspaceDisplay`, `modules` visibility switches, `components` visual replacement paths, `weather`, and `logo`. Keep its complete schema when editing it. Scale, colors, animation and clock format belong to the root. Settings validation applies independently to each file.

## Visual replacements

Each key under `components` matches a visibility switch under `modules`: `logo`, `workspaces`, `window`, `clock`, `music`, `capture`, `network`, `audio`, `battery`, `notifications`, and `tray`. An empty path uses the stock component. A nonempty path is absolute or relative to `astral-bar/`. Loading failure falls back to the stock visual and reports a warning. Visibility switches still apply. The Arch emblem stays visible when `modules.logo` is enabled, including when the launcher provider is empty. Clicking it opens the configured launcher when available.

Every replacement is an `Item` with `required property var context`. It supplies `implicitWidth` and `implicitHeight`; its actual size follows the slot. The live context always contains `tokens`, `vertical`, and `compact`. `tokens` is the shared Theme, with colors, sizes, durations, and `tokens.settings.value` for the composed settings. The following inputs and action methods are available on `context`:

| Slot | Additional inputs | Actions |
| --- | --- | --- |
| `logo` | `logoGlyph`, `logoImage` | `activated()` |
| `clock` | `dateTime`, `offsetSeconds` | `activated()` |
| `workspaces` | `spaces`, `specials`, `active`, `count`, `activeSpecial`, `display`, `interactive`, `step`, `normalLength` | `selected(workspace)`, `specialSelected(name)` |
| `window` | `title`, `available`, `expanded` | `activated()` |
| `music` | `media` (MediaData) | `activated()` |
| `capture` | `recording`, `captureState`, `duration` | `clicked()` |
| `network` | `connectionLabel`, `connectionDetail`, `strength` | `activated()` |
| `audio` | `volume`, `muted`, `audioDetail` | `activated()` |
| `battery` | `percent`, `discharging`, `batteryState`, `externalPower` | `activated()` |
| `notifications` | `count` | `activated()`, `summaryActivated()` |
| `tray` | `panel`, `navigation`, `nativeWindow` | use `navigation` to open/close the tray |

Optionally expose `hovered`, `ink`, `accent`, and `warning` on the replacement root for the shared hover and battery indicators. The wrapper also forwards stock component signals. External visuals can invoke context actions directly:

```qml
import QtQuick
Item {
  required property var context
  implicitWidth: 64
  implicitHeight: 40
  Text { anchors.centerIn: parent; text: context.volume + "%"; color: context.tokens.text }
  TapHandler { onTapped: context.activated() }
}
```

## External providers

Each provider is an argument array; `[]` disables it. The bar keeps unavailable session actions visible but disabled, and explains when all session providers are empty. Arguments are passed literally without shell interpolation. For example, `"launcher": ["/path with spaces/launcher", "--toggle"]` receives the monitor name as its final argument. The other provider keys are `lock`, `suspend`, `logout`, `reboot`, and `poweroff`; they receive no extra arguments. Do not put a shell command string in an array element.

Logout, reboot, and poweroff retain confirmation. Lock requires a configured lock provider. Suspend requires both providers: the bar invokes `lock`, then waits up to 15 seconds for a successful logind `LockedHint=yes` read before invoking `suspend`. The provider must set logind’s locked hint only after the compositor has confirmed a secure lock, and clear it after unlock. A correctly coordinated locker can report this through logind's `org.freedesktop.login1.Session.SetLockedHint` D-Bus method. A missing, failed or unknown logind state hides bar content and panels, suppresses notification popups, and suspends captures. Unknown state never authorizes suspend.

The built-in lock and session providers are installed on fresh full installations. Existing provider arrays remain unchanged. To enable the installed Astral locker after migrating empty providers, set `lock`, `suspend`, `logout`, `reboot`, and `poweroff` in root `settings.json` to `["astral-lock", "lock"]`, `["astral-lock", "suspend"]`, `["astral-lock", "logout"]`, `["astral-lock", "reboot"]`, and `["astral-lock", "poweroff"]`, respectively. Root `idle.qml` uses native idle notifications and handles logind sleep/lock events. Hyprland binds Super+L to `astral-lock` and Super+Escape to `astral-session`. Caffeine inhibits idle only and leaves lid policy to logind. Astral Polkit starts with the shell for graphical charge-limit authentication; run only one authentication agent per session.

## Installation and storage

`manage-configs.sh apply quickshell` installs only this tree and its ten public commands (`astral-shell`, `astral-bar`, `astral-launcher`, `astral-wallpaper`, `astral-polkit`, `astral-lock`, `astral-session`, `astral-clipboard`, `astral-overview`, `astral-shortcuts`). `--module astral-bar`, `--module astral-launcher`, `--module astral-wallpaper`, `--module astral-polkit`, `--module astral-lock` or `--module astral-session` includes the root common dependencies. `--source` accepts a QML file or an entry directory, with no settings or session helper requirement. Other identifiers require an external source; they are registered for manual startup by default. `--name` changes the destination remembered by commands.

A full destination snapshot precedes preference migration. Existing common preferences in the old bar/root settings are split into the new root; local preferences stay in the bar. Existing new-format settings and registries are preserved. Root `settings.json` is never retired. `--no-backup` explicitly skips snapshots; destination-only files and old commands remain. Back up and stop old module daemons before switching an existing installation.

`dispatch.sh` handles only public command dispatch. No bar, launcher, wallpaper, lock or session shell backend is installed. Privileged charge scripts remain under `system/power/`. State, cache and runtime use Astral's own XDG directories; screenshots and recordings use XDG Pictures and Videos. See [capture](captura-y-pantalla.md), [power](energia.md), and [validation](pruebas.md).

## Wallpaper

The built-in wallpaper uses root `wallpaper.qml` so imports of `common/` remain inside Quickshell's configuration boundary. Its selector and carousel stay closed at startup. The public command accepts `[toggle|carousel|daemon|close|close-active] [monitor]`, with a bare monitor name selecting `toggle`. The shell wrapper dispatches to `wallpaper-control.qml`; QML owns bounded readiness polling, IPC, and startup through `qs --no-duplicate`. A private flock held through a QML-managed process serializes concurrent command starts; its acknowledgement and release use stdin/stdout, with no shell helper. Close operations never start a service. A failed IPC query against a live service fails closed. External replacements need only their QML entry to run through the registry; supporting selector commands additionally requires the `wallpaper` and `wallpaper-carousel` IPC handlers (`state`, `toggle(monitor)`, `close`, `closeActive`).

`astral-wallpaper/library/StateStore.qml` preserves version 1 state at `$XDG_STATE_HOME/astral-shell/astral-wallpaper/state.json`, including independent theme, layout and disconnected monitor assignments. Invalid state falls back to defaults with a warning. FileView serializes atomic writes. Directories are private (0700), and preferences and the optional `api-key` file use 0600. Clearing the key leaves an empty private file. Shared Light/Dark changes reread and validate root settings, then atomically change only `mode`.

The local library defaults to `~/Pictures/Wallpapers`. Root `light/` and `dark/` subfolders select collections; other files are shared. `find` emits NUL-delimited paths and metadata; Qt JavaScript classifies and sorts them. PNG, JPEG, WebP, BMP, GIF, MP4, WebM and MKV are supported. Mirror, Span and Per monitor selections load across screens as a transaction. Failed or obsolete loads keep the previous wallpaper; missing active files are retained for the session. Unknown or locked logind state closes selectors and pauses animated wallpapers and rotation.

`thumbnails/` keeps at most 64 pending requests and runs at most two ffmpeg jobs, hashes each path with its current size and modification time, uses deadlines and publishes only completed files into `$XDG_CACHE_HOME/astral-shell/astral-wallpaper/`. `wallhaven/` requests SFW search results, validates pagination and download hosts, and stages image downloads beside their destination until ffmpeg validates them. Authenticated curl configuration goes through stdin; keys never appear in process arguments or error logs. Downloads are bounded to 100 MiB, search responses to 2 MiB. HTTP authentication failures, rate limits, offline requests, invalid data and interrupted transfers report errors without publishing partial wallpapers.

Run `bash tests/wallpaper/run.sh` for isolated service, persistence, thumbnail, network and command checks. With QtMultimedia available it also tests actual media, reusable renderer content, selector layouts and carousel behavior. `bash scripts/test-quickshell.sh wallpaper` opens an isolated selector and renderer window with generated samples. The `all` preview also substitutes this ordinary-window wallpaper entry. Neither preview creates background layer surfaces. Installer staging uses Astral's XDG cache; previews and tests create unique directories under Astral's XDG runtime (cache fallback); cleanup removes only each invocation's directory. Manual CachyOS checks remain necessary for compositor backgrounds, mixed-scale displays and video codecs. No dependencies or active dotfiles are changed during checks.

## Lock and session

Stock modules use root `lock.qml`, `idle.qml` and `session.qml`. The lock entry
is manual (`autostart=false`); the idle worker and closed session menu autostart.
Their shell wrappers only dispatch arguments to QML controllers.
`common/StartupLock.qml` serializes startup and power/caffeine changes;
`InstanceControl.qml` owns bounded readiness and instance checks.
`common/SessionService.qml`, user/media services and rounded clipping are shared
with the bar/launcher. Runtime coordination and parsing use QML and Qt JavaScript.

See [lock and idle](bloqueo-y-inactividad.md) and [session menu](sesion.md)
for settings, replacement IPC contracts, recovery and test commands.

## Clipboard, overview and shortcuts

Stock entries are root `clipboard.qml`, `overview.qml`, and `shortcuts.qml`; all three autostart by default. Controllers share `common/PanelControl.qml`, startup serialization, readiness timeouts, privacy checks, and strict absence detection. Closing never starts a module. External registry replacements need only their QML entry and the module's IPC contract. The launcher consults Polkit first during global close, then the session menu, wallpaper, bar, clipboard, overview, shortcuts, and launcher; unknown live replies block application close. Peer opening never cancels Polkit authentication.

Root `workspaceCount` (1–100, default 10) feeds both bar and overview directly. The installer moves the old bar value into root preferences when root has no value. `clipboard` defaults to `historySize: 50`, `maxImageBytes: 26214400`, `enterAction: "paste"`, and `pasteShortcut: {"mods":"CTRL","key":"v"}`. `overview.previews` defaults to true. Appearance comes from the shared theme.

See [clipboard](portapapeles.md), [overview](overview.md), and [shortcuts](atajos.md) for public commands, behavior and checks.
