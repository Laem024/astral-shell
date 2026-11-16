# Workspace overview

The active module lives in `config/quickshell/astral-overview/` and starts through root `overview.qml`. `astral-overview` accepts `toggle [monitor]`, `alt-tab next|previous`, `close`, `close-active`, and `daemon`.

`Alt+Tab` opens with the active workspace selected. Further presses cycle forward; `Alt+Shift+Tab` cycles backward. Releasing Alt confirms. Keyboard arrows, Enter, Escape and mouse selection remain available. Workspace cards retain live window thumbnails, window dragging between workspaces, and workspace moves between monitors. Root `workspaceCount` controls the shared workspace block size; `overview.previews` controls thumbnails.

`OverviewData.qml` reads Quickshell Hyprland models and dispatches validated actions through its API. Privacy checks guard actions; closing or locking cancels dragging, disappearing windows invalidate drops, and monitor changes cancel dragging. No bar subprocess supplies workspace counts.

Run `bash tests/overview/run.sh` and `bash scripts/test-quickshell.sh overview`. Preview uses ordinary windows with simulated workspaces and no window actions. Verify Alt release, real thumbnails, dragging and monitor disconnection on Hyprland before accepting the migration.
