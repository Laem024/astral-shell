# Validation

## Migration entry point

```bash
bash tests/quickshell/run.sh
bash tests/wallpaper/run.sh
bash tests/applauncher/run.sh
bash tests/lock/run.sh
bash tests/session/run.sh
```

The entry point runs Bash syntax checks, rejects legacy shell/module dependencies in the new QML runtime, exercises installation under temporary HOME/XDG paths, runs Qt JavaScript logic tests when QtTest is available, and parses QML syntax when qmllint is available. Missing Qt/Quickshell checks are explicitly reported as skipped. It installs no packages and does not apply active dotfiles.

`tests/quickshell/install.sh` checks dry-run behavior, full/partial/named installation, common dependencies, ten public commands, idempotence, migration and backup of common/local preferences, preservation of an edited registry/provider array, and external directory/file entries with spaces.

`tests/quickshell/tst_logic.qml` checks root/bar validation, provider argument arrays, duplicate registry IDs, registry autostart/disable filtering, absolute/relative QML paths, safe brightness mapping and readback interpretation, capture request validation and scaled/rotated monitor geometry.

`tests/quickshell/startup.sh` loads the real bar components in a disposable tree with headless window substitutes, catching entry-root, type-discovery and binding failures without a compositor. It leaves the live configuration untouched.

With `qs`, `tests/quickshell/runtime.sh` runs in a private D-Bus session with disposable configuration and mocked hardware commands. It checks external entry startup, duplicate prevention, isolated startup failure, disabled owned-process shutdown, settings error/recovery, fail-closed logind privacy, screenshot success/cancellation/failure, and worker heartbeat cleanup after the client is killed with mixed Bluetooth audio. Runtime checks must still be executed on a machine with Quickshell.

The previous settings/display/power shell entry points forward to the migration checks. Other focused bar checks remain under `tests/audio`, `bluetooth`, `media`, `network`, `notifications`, `panel`, `vpn`, and `weather`; they use the shared root theme and no pending locker shim. Clipboard, overview and shortcuts have active suites listed below.

## Other isolated checks

```bash
bash tests/configs/run.sh
bash tests/power/charge.sh
bash tests/power/install.sh
bash tests/power/setup.sh
bash tests/monitor/run.sh
bash tests/workspaces/run.sh
```

Privileged charge tests patch only a disposable helper copy and fake sysfs. `scripts/install-power.sh --stage` copies into a temporary directory. These tests do not modify live hardware or system service files.

## Graphical and hardware verification

```bash
bash scripts/test-quickshell.sh bar
bash scripts/test-quickshell.sh wallpaper
bash scripts/test-quickshell.sh launcher
bash scripts/test-quickshell.sh lock
bash scripts/test-quickshell.sh session
bash scripts/test-quickshell.sh all
bash scripts/manage-configs.sh apply quickshell --dry-run
```

Verify all four positions, multiple monitors, scaling, panel anchoring, keyboard interaction, tray, notification actions, custom replacements, valid/invalid settings reload, and missing providers. Test screenshots for monitor/region/window; recordings for monitor/region with none/system/microphone/mixed audio; cancellation and tool failures; closing a captured window; output disconnection; bar reload and bar death during recording; and restored audio modules, Bluetooth profiles and policy afterward. Test lid behavior and effective caffeine inhibitors, profile readback, charge authentication cancellation, and an unsupported battery.

Git metadata may be absent from a supplied workspace snapshot. When available, run `git status --short`, `git diff --check`, and review `git diff`. ShellCheck is optional; do not add it as a dependency.

Wallpaper checks exercise version 1 state recovery, library paths with shell metacharacters, bounded thumbnail queues, independent layouts and monitor changes, shared theme writes, unknown privacy, stale download cancellation, SFW search and pagination, stdin authentication, HTTP authentication/rate-limit/server errors, offline/invalid/interrupted downloads, simultaneous startup, and close without startup. Actual media and selector checks explicitly skip if QtMultimedia is absent. Scratch data uses unique directories under `$XDG_RUNTIME_DIR/astral-shell/tests` (XDG cache fallback); previews and installer staging also use Astral XDG cache directories and clean only their own invocation's directory. Wallpaper preview uses an isolated sample library in ordinary windows; it creates no compositor background surfaces.

## Hyprland shortcuts

Run `lua tests/keybindings.lua` to check shortcut registration, duplicate combinations and dispatcher names against the installed Hyprland Lua metadata. Run `bash tests/monitor/run.sh` for monitor privacy and lifecycle, and `bash tests/wallpaper/session.sh` for wallpaper command dispatch. After installation, check `hyprctl configerrors` and verify `Super+Q` with a disposable window, both wallpaper shortcuts, and `Ctrl+Shift+Esc`.

Launcher tests use the active module, private Astral XDG scratch and fictional
commands. They cover catalog precedence, accent search, ranking, favorites,
history, corrupt state, persistence, storage failure, literal arguments, failed
launch requests, concurrent startup, monitor arguments, privacy, ordered close
and unknown IPC replies. Headless windows exercise the real launcher visual tree;
manual CachyOS checks still cover focus, actual screen removal and compositor
animations. The launcher preview and its `all` variant use a simulated service.

`tests/applauncher/run-live.sh` and `tests/notifications/run-live.sh` additionally use an accessible systemd user
manager to verify literal arguments and working directories, then reloads and
stops its isolated Quickshell harness while a bounded fictional application
child remains alive. It explicitly skips when the manager is unavailable.

`bash tests/polkit/run.sh` checks simulated authentication, privacy and startup coordination. `bash scripts/test-quickshell.sh polkit` opens a non-registering demonstration; `all` uses the same demo. Real authentication, exclusive focus and monitor switching require manual CachyOS validation with one agent.

## Clipboard, overview and shortcuts

Run `bash tests/clipboard/run.sh`, `bash tests/overview/run.sh`, and `bash tests/shortcuts/run.sh`. Clipboard checks use mocked wl-clipboard and systemd tools to verify binary NUL/non-UTF8 integrity, MIME priority and sensitive markers, deduplication, queue ordering, limits, corrupt history preservation and explicit recovery, copy confirmation, lock during capture, and unknown privacy. Overview checks cover workspace blocks, active selection, cycling, window and monitor commands. Shortcuts checks cover JSON loading, categories, search, modifier filtering and navigation.

`bash tests/panels/startup.sh` loads production UI on offscreen surfaces and checks ordinary sample previews. `bash tests/panels/control.sh` checks simultaneous startup, external entries, absent close and unknown responses for all three controllers. Both are included in `tests/quickshell/run.sh`. Tests use Astral-specific XDG storage; use a short runtime path because Unix socket names have a length limit.

Use `bash scripts/test-quickshell.sh clipboard`, `overview`, or `shortcuts` to inspect ordinary windows with sample data. On CachyOS with Hyprland, still verify real image capture/copy and pasted bytes, Alt+Tab first press/subsequent cycling/Alt release, thumbnails, drag/drop, monitor removal during dragging, reload-driven shortcut refresh, and locking during paste. Automated mocks do not establish compositor or clipboard protocol behavior.

## Scratch and integration checks

All suites use `tests/xdg-scratch.sh`, which freezes the scratch root before HOME/XDG overrides, creates private unique directories under Astral XDG runtime (cache fallback), and rejects paths too long for IPC. Test D-Bus configurations and sockets are private and removed with their owning invocation. Run `bash tests/scratch/run.sh` for concurrency, cleanup, cache fallback and long-path diagnostics.

Weather checks initialize the default clock visual, verify wrapper date/offset forwarding, and run online, cached offline and system fallback scenarios using XDG cache. Wallpaper theme checks compare objects structurally and verify saved/reloaded settings; only `mode` may change. Workspace checks include a named installation without a bar and a contradictory legacy bar count.

Before calling the shell ready, verify on CachyOS: a workspace count other than ten (count five, workspace six, first shortcut stays at six), actual notification file/folder openings, pending-lock privacy, idle display power, automatic suspend and resume. Mock results do not establish these compositor/hardware behaviors.
