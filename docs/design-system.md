# Astral design system

One visual language shared by Quickshell, SDDM, Kitty, Fish, btop, GTK/Qt and Hyprland. The UI is in English. Dark and light modes are both first-class.

## Palette

The source of truth for Quickshell is `config/quickshell/settings.json` (`colors.dark` and `colors.light`), mirrored in `config/quickshell/common/Defaults.js`. Other applications carry the same hex values.

| Role | Dark | Light |
| --- | --- | --- |
| background | `#0E1113` | `#EEF2EF` |
| surface | `#171C1F` | `#FBFCFA` |
| text | `#E7ECE9` | `#141B1D` |
| muted | `#8D9994` | `#5A6764` |
| cyan (primary accent) | `#7FD0BF` | `#17675A` |
| lavender (secondary accent) | `#A9B5D9` | `#3B4A7A` |
| gold (tertiary accent, warnings) | `#E5B873` | `#8A5B16` |
| alert (destructive, errors) | `#F08C7B` | `#A9361F` |

Derived tones (`raised`, `sunken`, `border`, `hairline`, `scrim`) are computed in `common/Theme.qml`. Do not add new palette keys without updating `common/Validation.js`.

## Shape and spacing

- Panels: radius 20. Cards: radius 14. Rows and inputs: radius 10. Pills and round buttons: fully rounded.
- Spacing uses the 4 px unit: 4, 8, 12, 16, 24.
- Every surface keeps at least 16 px of inner margin and never clips its content. Text must elide or wrap rather than overflow.
- Content is centred within its container. Lists scroll rather than grow past the screen.

## Typography

- UI text: `sans-serif`. Technical values, shortcuts, paths and clocks: `JetBrainsMono Nerd Font`.
- Sizes: caption 10–11, body 13, label 14, title 16–18, display 28+.

## Behaviour

- Hover and focus are visible without colour alone (an outline or a tone change).
- Destructive actions use `alert` and require confirmation.
- Animations follow `settings.animations`; when disabled, durations are zero.

## Mode switching for non-Quickshell apps

Dark is the default everywhere. Each switch below is a file copy or a single command; nothing is installed.

- **Kitty**: `config/kitty/kitty.conf` includes `palette.conf` (dark). To switch: `cp ~/.config/kitty/palette-light.conf ~/.config/kitty/palette.conf`, then `pkill -USR1 kitty` to reload running instances. Reverse with `palette.conf` from the repo.
- **btop**: `color_theme` in `config/monitor/btop.conf` selects `astral` (dark) or `astral-light`. Set `color_theme = "astral-light"` for light mode; the monitor picks it up on next launch.
- **Fish**: `astral_mode dark` or `astral_mode light` writes the universal `fish_color_*` variables. The prompt reads them, so it follows the mode in every new shell.
- **Hyprland**: set `local mode = "dark"` or `"light"` in `config/hyprland/modules/appearance.lua`, then reload. For Hyprtoolkit, copy `hyprtoolkit-light.conf` over `hyprtoolkit.conf`.
- **GTK 3/4**: `gtk-application-prefer-dark-theme` in `settings.ini` is `1` (dark). For light, set it to `0`. The GTK theme (`catppuccin-mocha-…`) is dark-only, so a light GTK theme must be chosen separately for full light mode.
- **Qt5ct/Qt6ct**: unchanged. They do not yet use the Astral palette, so they follow their existing style.

## Invariants

These must not change during visual work:

- Hyprland keybindings and keyboard layout.
- The workspace count (`workspaceCount` in `settings.json`, default 10).
- Every provider, command, IPC call, storage path and privacy policy.
- No new packages, programming languages, or references to folders outside the project and standard XDG locations.
