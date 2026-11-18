# Bar and panels

The new bar lives in `config/quickshell/astral-bar/`. It retains the original visual implementations under `modules/Default*.qml`, reusable components under `components/`, and panel presentation under `panel/`. `AstralBar.qml` creates one window per screen, supports top/bottom/left/right anchoring, and reserves the bar's margins without double-counting the opposite edge.

`BarContent.qml` composes the launcher emblem, clock/calendar, active window, workspaces, media, capture, tray, network, audio, battery and notifications. Each slot keeps its visibility switch and can load an external visual through `settings.json`'s `components` paths. The wrapper preserves live input bindings and replacement contracts. Default visuals use icon tone changes on hover and visible keyboard focus, without floating hover boxes. See the complete [replacement contract](quickshell.md).

Normal workspace selection is square; the special selector stays circular. Status nodes use tinted line icons with a small status label and value. Compact mode keeps icons and indicators. All four positions keep the outer surface and segment plates.

`panel/PanelState.qml` owns navigation across monitor bars. The floating native panel presents network/Wi-Fi/Bluetooth/VPN, audio routing, media, notifications, display/capture, power, weather/calendar and window actions. Opening a panel does not automatically call pending Astral modules. Shared colors and sizes come from root `common/Theme.qml`; the bar settings adapter combines root common preferences with bar-specific options.

## Control center design

The central popup uses a 760 × 760 logical-pixel canvas, bounded by the available screen and shared scale. `panel/ProfileHeader.qml` combines a cropped banner, a theme-colored orbital fallback, an editable portrait, the account display name and username. “Edit banner” and the portrait open the existing image pickers; the banner crop preview follows the header's current aspect ratio.

Seven English categories use native line icons from `panel/CategoryGlyph.qml`. Navigation collapses to icons with tooltips on narrow screens. `panel/PageIntro.qml` provides category titles and live summaries; `PanelCard.qml` provides tinted section surfaces. All colors, corners, typography and animation timing come from the common shell theme, including light mode and disabled animations.

- **Calendar:** month navigation, a gold today marker, weather metrics and the week forecast.
- **Music:** a category banner with live playback status, an immersive album sleeve, player selection, timeline and a rounded transport deck.
- **Connections:** Wi-Fi, Bluetooth and VPN tiles with live summaries, followed by their existing management controls.
- **Screen & captures:** a capture studio with source tiles, audio options, saved-file actions and display brightness.
- **Sound:** output and microphone cards side by side when space permits, followed by the application mixer.
- **Power & session:** an energy ring, power profiles, caffeine, battery care and confirmed session actions.
- **Notifications:** a quiet-mode card, history actions and an illustrated empty state.

`bash tests/panels/central.sh` checks all seven pages at three window sizes, plus light mode, using private XDG directories and mocked hardware commands. It also runs with `bash tests/quickshell/run.sh`. Set `ASTRAL_PANEL_SNAPSHOTS` to an existing directory to save local screenshots of the seven pages.

`data/` owns services; JavaScript files own validation and transformations. Existing NetworkManager, Bluetooth, PipeWire, MPRIS, notifications and UPower integration remain. Display, recording, power and privacy coordination use the new QML backend. Notifications suppress popups and sounds when the session is blocked; the bar hides sensitive content for locked or unknown logind state.

Weather cache writes use FileView's atomic replacement in `$XDG_CACHE_HOME/astral-shell/astral-bar/weather.json`. The profile banner uses an atomically published manifest and a private managed image copy under `$XDG_STATE_HOME/astral-shell/profile/`. Avatar preparation uses Astral's XDG runtime directory.

Run `bash scripts/test-quickshell.sh bar` for visual verification. Check four positions, monitor hotplug, scale, custom colors, animation settings, workspace counts, hidden slots, custom replacements (including failed loads), panel anchoring, tray menus, notification actions, keyboard navigation and narrow screens. Automated checks are described in [validation](pruebas.md).

The segment plates and logo border frame the controls, with static cyan details at both bar ends. The expanding hover line and its vermilion marker have been removed. Horizontal time and date sit side by side; background applications follows a divider after the player, and Screen & capture starts the status dock. Workspaces retain their hover outline; other bar modules use color feedback without individual hover rectangles. Status instruments pair a tinted disc with a label and value.
