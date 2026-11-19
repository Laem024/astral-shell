# Installation and configuration management

Use a regular user account on CachyOS. Never rename the machine account or home directory when changing the project name. Back up active configuration before applying a new setup.

## Machine setup

```bash
./install.sh
./install.sh update
```

The entry point runs package selection, service setup, configuration copying, keyd setup, SDDM setup and power setup. Package and system operations request privileges through their installers. A failed step stops later steps. Review package catalogs in `packages/` before using the complete installer. Validation and preview use the dependencies already installed.

Both modes install the required `keyd` package, migrate the [numeric keypad profile](hyprland.md#numeric-keypad) and enable `keyd.service`. Replacing an existing default profile creates a separate system backup under `/etc/keyd/`.

Prerequisites include Bash, systemd, the CachyOS repositories, Hyprland/Wayland, Quickshell, PipeWire and its PulseAudio compatibility service, and the existing tools used by enabled controls. Optional external actions remain hidden until configured. Graphical charge authentication uses Astral Polkit, which starts with the shell. Run only one authentication agent per session.

## Review and apply configurations

```bash
bash scripts/manage-configs.sh apply quickshell --dry-run
bash scripts/manage-configs.sh apply quickshell
bash scripts/manage-configs.sh apply quickshell --module astral-bar
bash scripts/manage-configs.sh apply quickshell --module astral-bar --name personal
bash scripts/manage-configs.sh apply quickshell --module astral-bar --source '/path with spaces/my-bar'
bash scripts/manage-configs.sh apply quickshell --module custom --source '/path/custom.qml'
```

The Quickshell source is `config/quickshell/`. The old tree is reference only. A custom source is a readable QML file, or a directory containing `shell.qml`. Settings and session helpers are optional for external modules. `astral-bar`, `astral-launcher`, `astral-wallpaper`, `astral-polkit`, `astral-lock` and `astral-session` support stock partial installation; other module identifiers require an explicit external source. New external identifiers are added to the registry with autostart disabled. A custom-only installation does not register an absent stock bar or repoint its public command.

Partial installation includes `common/`, the root entry, dispatcher and root settings. Shared dependencies are installed once. The ten supported public Quickshell commands are listed in README; module commands are installed when their entries are present. Each command embeds the absolute selected destination. The bar supports `start`, `daemon`, and `close-panels`. `astral-shell workspace-count` reads the installed root settings without starting Quickshell; `astral-bar workspace-count` aliases that query.

Destinations use `$XDG_CONFIG_HOME`, falling back to `~/.config`; Quickshell uses its `quickshell/` directory and `--name` chooses a child directory. `apply all` also installs the other repository configurations. `monitor` installs `astral-monitor` independently of Quickshell.

The manager checks source/destination safety and backs up the entire existing destination under `.backups/<timestamp>-<id>/` before writes. It verifies the backup before copying files. Existing public commands are backed up before replacement. Identical reapplication does not create another backup. Settings are merged by known schema keys and type, keeping missing values at defaults. Existing new-format preferences and module registries remain authoritative. Old common values are separated from bar-local values after backup. The new root `settings.json` is retained.

`--dry-run` reports copying, preferences and command plans without destination writes. It can review a read-only destination; a real apply additionally checks write access. `--no-backup` explicitly skips configuration and command backups. Destination-only files and old public commands remain, so stop old module daemons before switching configurations. No legacy `shared/` directory or root settings file is automatically deleted.

## Preview and rollback

`bash scripts/test-quickshell.sh all`, `bar` or `wallpaper` uses a unique copy with isolated XDG runtime/cache/state. Wallpaper uses an isolated sample library and ordinary windows. Its cleanup targets only entries from that copy. Capture output still uses Pictures and Videos. Without `qs`, preview reports the missing prerequisite and exits.

To roll back, stop the new Quickshell entries, restore the chosen configuration backup, and restore the corresponding command backups from `~/.local/bin/`. Power system files use separate backups from `scripts/install-power.sh`; inspect those before restoring. See [validation](pruebas.md), [power](energia.md), and [SDDM](sddm.md).

Install the launcher alone with `--module astral-launcher`; `--source` supports an
external QML replacement. Root launcher entries and its QML controller are included
in partial installations. Existing settings, provider overrides and backups follow
the same preservation rules as the bar and wallpaper.

## Clipboard, overview and shortcuts

Full installation includes `astral-clipboard`, `astral-overview`, and `astral-shortcuts`. Install one with `bash scripts/manage-configs.sh apply quickshell --module astral-clipboard` (or the other module name). `--source /path/to/main.qml` registers an external replacement. Shared root dependencies and the public controller command are included in partial installs.

The installer preserves root preferences and existing registry paths, enabled states and autostart choices. When absent from root, the old bar `workspaceCount` and module-local clipboard/overview preferences are migrated after backup. Legacy clipboard JSON stays in XDG state. Do not run the old clipboard daemon alongside the active service.

Astral Idle owns automatic locking, display power and suspend; preferences live in `config/quickshell/settings.json`. Hypridle is no longer a project dependency. Applying Hyprland removes only exact copies of the retired project helper/config after the usual backup; customized copies require manual review. Dry runs and `--no-backup` are respected. External idle processes and installed packages are left to the user.
