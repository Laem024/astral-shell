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

- Default bar modules use subtle icon and text tones on hover, with no per-module hover plates or floating tooltips; the workspace hover outline remains. Keyboard focus keeps a visible outline and accessible names.
- Destructive actions use `alert` and require confirmation.
- Animations follow `settings.animations`; when disabled, durations are zero.

## Astral depurado composition

- The bar keeps its outer surface, segment plates, logo border and static cyan accents at both ends in all four positions. Connection, volume, battery and notification instruments share line icons and short values; compact mode keeps icons and indicators. Normal workspace selection is square, special selection stays circular, and both retain their transitions.
- Horizontal bars place time and date side by side in a 40 px control. Modules share a vertical center; the background applications chevron follows the player and a divider, and shares the status dock with screen capture at a 2 px gap. The launcher emblem uses a four-point star with alternating light and shadow facets, a bright diamond center and a 90-degree hover rotation. The capture glyph is 20 px. Media artwork has internal padding inside its hover border; compact media reserves an 8 px gap before transport controls. Horizontal notifications keep a 12 px inset from the group edge; compact system controls use 32 px widths. Bar controls do not show native hover tooltips. There is no divider between background applications and capture.
- Sound starts with compact output and microphone controls, then application streams. Connections uses Wi-Fi/Bluetooth/VPN tabs and one visible section; switching tabs keeps transport controllers alive.
- Media artwork uses `astral-bar/components/RoundedClip.qml` in the bar and player. Scrollable content and selectors remain available on small panels.
- The launcher is a compact search window with category tabs and application rows containing icon, name, available description and favorite control.
- Session actions use five balanced cards on wide screens and wrap into three or two columns on smaller screens. The grid scrolls vertically to reveal the focused action; confirmation keeps its hold timer and progress ring even when decorative animations are disabled.
- SDDM places the form at the left and clock at the right, with a centered composition on small screens. Background presets, custom images, stars and other theme options remain configurable.

## Visual validation

Run the Quickshell, launcher, session and SDDM suites, including `tests/sddm/greeter.sh`.
Media layout checks assert square normal and circular special selectors; launcher
checks exercise list navigation, favorites and Escape; session checks cover focused
action wrapping, vertical scrolling and hold cancellation. Media checks also open the player selector
inside its rounded viewport. Audio, NetworkManager, Bluetooth and VPN suites cover
existing device and failure flows.

Review isolated previews in dark/light modes, with scaling and animations disabled,
at all four bar positions and on small screens. Qt's RHI renderer is needed to inspect
rounded shader masks; software-only rendering does not display those effects.
Real compositor focus, monitor hotplug and hardware behavior still need an interactive
CachyOS session before installation.

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
