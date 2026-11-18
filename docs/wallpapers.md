# Wallpaper

`config/quickshell/astral-wallpaper/` is the active QML wallpaper module. It starts with `astral-shell`, with selector windows closed. Its historical implementation remains in `config/quickshell-old/` for reference and is never installed or launched.

```bash
astral-wallpaper                 # Toggle the selector on the focused monitor
astral-wallpaper DP-1            # Toggle on a named monitor
astral-wallpaper carousel DP-1   # Toggle the carousel
astral-wallpaper daemon          # Ensure the background is running, without opening windows
astral-wallpaper close           # Close both windows without starting the service
astral-wallpaper close-active    # Report closed/inactive; fail on an unknown live-service state
```

The Library tab opens `~/Pictures/Wallpapers` by default. Choose another absolute folder in the selector. Images under root `light/` or `dark/` folders belong to that theme; other files are shared. Light/Dark changes the shared shell theme while preserving other settings. PNG, JPEG, WebP, BMP, GIF, MP4, WebM and MKV are supported. Choose Mirror, Span or Per monitor; assignments are retained independently for each theme and layout, including disconnected displays. Rotation supports sequential or random order and pauses with animated backgrounds when logind is locked or unknown. A damaged or missing replacement keeps the previous background.

Wallhaven loads the latest SFW wallpapers when its tab opens or the selector reopens on that tab. An empty search also sorts by newest unless an explicit sort filter is selected. Search filters cover General/Anime/People categories, SFW/Sketchy/NSFW content (SFW by default; NSFW requires a saved API key), sorting, order, toplist period, minimum or exact resolution, aspect ratio and Wallhaven's color palette. Apply filters with Search; Latest / Reset clears them. Query syntax supports tags, exclusions, usernames, exact tag IDs, file types and similar-wallpaper IDs. Pagination preserves the submitted filters and the random seed. The saved API key is loaded before the service becomes ready and used for searches, including the initial latest listing. See the [Wallhaven API reference](https://www.whvn.cc/help/api) for allowed values.

Wallhaven supports pagination, optional API-key storage and validated downloads into the selected collection. The API key goes to curl through stdin, never arguments or logs. Failed and partial downloads are not published. Preferences and the key use private files under `$XDG_STATE_HOME/astral-shell/astral-wallpaper/`; thumbnails use `$XDG_CACHE_HOME/astral-shell/astral-wallpaper/`. Defaults are `~/.local/state` and `~/.cache` respectively.

Install with `bash scripts/manage-configs.sh apply quickshell`, or add only wallpaper and shared dependencies with `--module astral-wallpaper`. External replacements need only an entry QML file; registry paths, disabled modules and custom providers are preserved. The new registry entry is added if missing. Back up and stop historical wallpaper daemons before switching; no automatic conversion runs against active dotfiles during tests. See [configuration and replacement contracts](quickshell.md#wallpaper).

Run `bash tests/wallpaper/run.sh` for isolated validation and `bash scripts/test-quickshell.sh wallpaper` for an ordinary-window preview with generated samples. Preview never changes compositor backgrounds. QtMultimedia QML, ffmpeg, curl and find must already be available; no dependencies are installed automatically. Test actual background surfaces, mixed scaling, monitor hotplug and codecs manually on CachyOS.

Carousel cards render to a filtered texture at twice their logical resolution with transparent edge padding before perspective rotation, keeping the side silhouettes smooth.
