# Repository Guidelines

## Project Structure & Module Organization

`astral-shell` is a personal shell environment for CachyOS (Arch-based).
Configuration lives in `config/`, installers and configuration management in
`scripts/`, system services in `system/`, and isolated checks in `tests/`.
The active Quickshell migration contains an orchestrator at
`config/quickshell/shell.qml`, shared configuration and theme under `common/`,
and `astral-bar/`, `astral-launcher/`, `astral-wallpaper/`, `astral-polkit/`,
`astral-lock/`, `astral-session/` and `astral-settings/`. Launch stock modules through root
`bar.qml`, `recorder.qml`, `launcher.qml`, `wallpaper.qml`, `polkit.qml`,
`lock.qml`, `idle.qml`, `session.qml` and `settings.qml`; entries below the root cannot import shared
parents through Quickshell’s URL interceptor. Keep explicit `qmldir` type
indexes in module directories with hyphenated ancestors. The root `settings.json` owns shared appearance,
applications, optional argument-array providers, and the module registry. Bar
preferences and visual replacement paths live in `astral-bar/settings.json`.
`config/quickshell-old/` is reference only; do not install or autostart it.
Clipboard, overview and shortcuts are active modules with root entries and QML controllers. Shared workspaceCount lives in root settings.json. External modules need only their QML entry point.
Install only the `astral-shell`, `astral-bar`, `astral-launcher`, `astral-wallpaper`,
`astral-polkit`, `astral-lock`, `astral-session`, `astral-clipboard`, `astral-overview`, `astral-shortcuts` and `astral-settings` public
Quickshell commands. Wallpaper preferences and the optional Wallhaven key live
in XDG state; its bounded thumbnail queue uses XDG cache. Shared privacy and
popup dismissal policies live in `common/`. Runtime wallpaper and launcher coordination
belongs in QML; public dispatch belongs in `dispatch.sh`.
Runtime coordination uses QML, Quickshell APIs and Qt JavaScript; shell is
limited to installation, tests and public command dispatch. Keep privileged
charge administration scripts in `system/power/`. Providers receive separate
arguments; never interpolate user settings into shell commands. Use logind's
locked hint for privacy and fail closed on unknown state. Recording and caffeine
run in independent QML workers; preserve heartbeat cleanup, audio/profile
restoration and effective inhibitor verification. Use Astral-specific XDG
runtime/cache/state directories, and Pictures/Videos for captures.
The resource monitor is separate from Quickshell: `config/monitor/` installs
`astral-monitor`, which opens `btop` in `kitty` on the `special:resources`
Hyprland workspace.
Hyprland and Quickshell use installed public commands. Pending module bindings
and automatic calls stay disabled until a provider or migrated module exists.
Never rename the machine account or home directory when changing project names.

Keep new configuration files and scripts grouped by purpose, and document their locations in `README.md`. Avoid introducing a directory hierarchy until there are files that need it.

## Build, Test, and Development Commands

There is no build system or local development server. Isolated shell and QML checks live in `tests/`; QML checks may require D-Bus and Quickshell. Use `bash tests/quickshell/run.sh` for the orchestrator/bar migration and
`bash tests/wallpaper/run.sh` for wallpaper services and rendering,
`bash tests/applauncher/run.sh` for launcher services, persistence and IPC,
`bash tests/polkit/run.sh` for isolated authentication and startup flows, and
`bash tests/lock/run.sh` and `bash tests/session/run.sh` for lock/session flows.
Use `bash scripts/test-quickshell.sh bar`, `wallpaper`, `launcher`, `polkit`,
`lock`, `session` or `all` for isolated preview.
Wallpaper previews use a private sample library and ordinary windows, never
compositor background surfaces. Installation staging, checks and previews use
Astral-specific XDG directories, never `/tmp` or `/temp`. Graphical
and hardware checks require CachyOS with Quickshell. Do not install dependencies
automatically. Use these repository checks when preparing changes:

- `git status --short` — inspect changed and untracked files.
- `git diff --check` — catch whitespace errors before committing.
- `git diff` — review changes for unintended configuration edits or sensitive values.

For future Bash scripts, run `bash -n path/to/script.sh` to check syntax. If ShellCheck is installed, run `shellcheck path/to/script.sh` for additional diagnostics. These tools are recommendations, not existing project dependencies.

## Coding Style & Naming Conventions

Use clear Markdown headings and short instructions in documentation. For new shell scripts, use descriptive lowercase, hyphen-separated filenames, such as `setup-shell.sh`, and a shebang matching the intended interpreter. Use consistent indentation within each file; prefer two spaces for new shell code. Quote variable expansions and explain commands that alter the user's environment.

No formatter or linter configuration is currently committed.

## Testing Guidelines

No testing framework or coverage threshold is configured. Use the existing isolated checks for the affected subsystem. For shell changes, check syntax and manually verify behavior on CachyOS before proposing integration. Describe the commands tested, expected results, and any untested behavior in the pull request. Test installation or configuration changes in a temporary environment before applying them to active dotfiles.

## Commit & Pull Request Guidelines

History contains `Initial commit` and `chore: first commit add empty .gitignore`; a comprehensive convention is not established. Prefer short, imperative subjects with a relevant prefix, such as `chore:`, `docs:`, or `fix:`.

Keep pull requests focused. Explain the purpose, affected files, validation performed, and any manual setup or rollback steps. Link related issues when applicable.

## Security & Configuration Tips

Never commit credentials, private keys, tokens, or machine-specific secrets. Add appropriate ignore patterns before introducing generated files or local overrides. Document prerequisites and back up existing configuration before replacing it.

Launcher state retains version 1 JSON under XDG state. ApplicationLaunch uses
Type=exec and ExitType=cgroup user services with literal arguments and disabled
environment expansion. Shared Overlays owns peer dismissal; launcher-control.qml
owns ordered global close and fails closed on unknown privacy or peer replies.

Polkit uses the native agent at `/org/astral/shell/PolkitAgent`. Its controller
serializes startup and checks registration with at most three attempts; never
stop external agents. Destroy its dialog immediately on blocked or unknown
privacy, clear responses on every flow transition, and consult Polkit first in
global close. Peer panel opening must never cancel authentication.

The lock owns PAM and WlSessionLock in an independent process. No unlock IPC
is permitted. Publish logind's locked hint only after compositor confirmation;
clear it and the pending runtime marker only after authenticated unlock.
Native idle notifications and the logind delay inhibitor live in `astral-lock/`.
Recheck media, caffeine, inhibitors and activity after locking before automatic
suspend. Shared session actions, user/media services and startup coordination
live in `common/`; keep the lock entry out of autostart.

Astral Settings lives in `config/quickshell/astral-settings/`; its root controller
uses the shared startup lock. Keep display transactions in the daemon, independent
of the window. Persist display overrides only after confirmation and restore on
expiry, close, privacy block, command failure or restart. Desktop preferences and
the recovery journal use version 1 JSON under XDG state; managed confirmed Lua
lives under `$XDG_CONFIG_HOME/astral-shell/astral-settings/`. The final Hyprland
module validates the entire data table before applying overrides. Never force HDR
capabilities. Settings previews simulate desktop operations; do not change real
input, monitors or theme files. Run `bash tests/astral-settings/run.sh` for this
subsystem (also included in the Quickshell suite).
