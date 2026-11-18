# Capture and display

The Display panel keeps monitor/region/window screenshots and monitor/region recordings. Audio modes are none, system, microphone, and both. Preferences remain in the Astral state directory through Qt settings.

Screenshots and recordings default to the monitor whose bar opened the panel.
You can choose another display for the current page. Reopening the page selects
its own monitor again; if that monitor is unavailable, the saved selection or
the first connected display is used.

## Implementation

- `astral-bar/data/BrightnessData.qml` coordinates reads and writes; `BrightnessLogic.js` validates values and maps outputs. Internal panels require exactly one internal monitor and one backlight device. External displays require one matching DRM connector and its resolved DDC I2C bus. Enumeration order is never used to guess a mapping. Writes re-resolve the mapping after hotplug and read back the applied value. The model preserves delegates during updates and coalesces slider writes.
- `CaptureData.qml` handles bar presentation, native window frames, and recording IPC. Capture starts after the panel has disappeared and the compositor has had time to remove it.
- `CaptureJob.qml` coordinates directory selection, file allocation, region selection, monitor validation, screenshots, recorder lifetime, and cleanup. `CaptureLogic.js` validates requests and checks region containment using scale and rotation.
- `display/WindowCapture.qml` uses Quickshell screencopy and Qt image saving for a native window screenshot. Closing the window, timeout, or failed saving cancels the operation.
- `recorder.qml` and `display/RecorderRoot.qml` is a separate `qs` instance. It receives `recorder.start(token, JSON)`, `beat(token)`, `stop(token)`, and `status()` IPC calls. It checks logind privacy and output presence. A client heartbeat expires after four seconds; the worker then signals its recorder to finalize and restores audio. Losing or reloading the bar therefore does not kill the encoder as an ordinary bar-owned Process would. The worker exits after its idle timeout.
- `CaptureAudio.qml` coordinates PulseAudio compatibility tools and Bluetooth policy. It rejects a monitor source masquerading as a microphone and rejects muted microphones. System audio uses the sink monitor; mixed audio creates an owned null sink and loopbacks. Cleanup unloads those modules in reverse order, restores changed card profiles, then restores WirePlumber's autoswitch setting. An in-use Bluetooth microphone keeps its profile. Headset microphone mode pins HFP before starting streams and checks transport errors during recording.

Commands are argument vectors passed to Process. There is no `capture.sh`, brightness helper, or result-opener helper in the new runtime. Notification file actions start configured applications through transient systemd user services with literal arguments and environment expansion disabled. Exec-type startup verifies the executable; the service and its output survive bar reload. Folders use a terminal fallback when the file manager cannot start.

## Output and failure behavior

Files are allocated with `mktemp` under the XDG Pictures/Screenshots or Videos/ScreenRecordings directory, falling back to `$HOME/Pictures` or `$HOME/Videos`. Cancelled/failed screenshots and empty recordings are removed. Nonempty failed recordings are retained as potentially incomplete, with an error. A stop uses SIGINT and waits for finalization; an unresponsive recorder is killed after 15 seconds and reported as incomplete. The worker owns audio cleanup through that sequence.

Any missing, locked or unknown logind session state blocks new captures and stops an active recording. Disconnecting the recording output stops recording. Region recordings must fit exactly one monitor. The selector receives an explicit stdin EOF before selection, so it cannot block waiting for optional input rectangles. Selection cancellation returns to idle without a saved-file notification; a selector error is reported. During a screenshot, the bar keeps the capture glyph and offers cancellation. The video stop icon and elapsed timer appear only during recording. The existing window capture API still depends on compositor screencopy support.

## Checks

Run `bash tests/quickshell/run.sh`. Qt tests check geometry, scale/rotation, request validation and brightness mapping. With `qs`, the disposable runtime fixture checks monitor and region screenshot success, selector stdin closure, selection cancellation without notifications, screenshot and video indicators, screenshot failure, unknown privacy state, and heartbeat cleanup with mixed Bluetooth audio. The fixture uses simulated tools; it does not establish real hardware correctness.

On CachyOS, also check all four bar positions and multiple monitors, actual brightness keys/sliders, DDC permissions and hotplug, window closure during capture, Escape during selection, microphone mute, all audio modes, Bluetooth transport failure, killing/reloading the bar during recording, unplugging the recording display, and restoration of profiles/modules after each failure. Compare audio state before and after the operation.
