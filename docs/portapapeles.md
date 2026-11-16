# Clipboard history

The active module lives in `config/quickshell/astral-clipboard/`, entered through root `clipboard.qml`. The public command accepts `open`, `paste`, `delete`, `toggle [paste|delete]`, `clear`, `close`, `close-active`, and `daemon`. `Super+V` opens paste mode, `Super+Ctrl+V` opens delete mode, and `Super+Ctrl+Shift+V` explicitly clears history.

Root `settings.json` owns `clipboard.historySize` (1–500), `maxImageBytes` (1–1073741824), `enterAction` (`paste` or `copy`), and `pasteShortcut` (modifier/key object). Theme and scale use common settings. The panel retains text/image previews, keyboard selection and per-entry removal.

`ClipboardService.qml` owns a single operation queue. `wl-paste --watch printenv CLIPBOARD_STATE` notifies QML; it queries MIME types and chooses an image before text. Sensitive callbacks and the KDE password-manager hint are ignored. SHA-256 deduplicates exact bytes. Images flow through binary collectors and FileView without text conversion. Version 1 JSON and images live under `$XDG_STATE_HOME/astral-shell/astral-clipboard/`, protected by private directory/file permissions, a service lifetime lock, atomic writes, bounded history and orphan-image collection. Image paths outside managed storage are rejected. Corrupt history is retained and blocks writes until an explicit clear; back it up before clearing.

Copy uses a systemd user service with literal arguments, `wl-copy --foreground`, disabled environment expansion and a specifier-escaped `StandardInput=file:` path. The service confirms the selected bytes with wl-paste before signaling success. The panel rechecks privacy after its close animation before sending the configured paste shortcut. Locked or unknown privacy stops watching and invalidates pending work; unlocking resumes notifications without importing the retained selection.

Run `bash tests/clipboard/run.sh` and `bash scripts/test-quickshell.sh clipboard`. Preview uses sample text and disables actions. Real Wayland image capture/copy and locking during paste require manual verification on CachyOS. See [validation](pruebas.md).
