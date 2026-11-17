# Session menu

The active module lives in `config/quickshell/astral-session/`, through root
`session.qml`. QML handles its menu, keyboard input, confirmation and process
lifecycle. Qt JavaScript in `Logic.js` defines actions and shortcuts. There are
no module shell backends or additional runtime dependencies.

After installation, `astral-session` toggles the menu on the focused monitor.
It also accepts `daemon`, `close` and `close-active`. Startup is serialized and
waits for readiness. Closing never starts a service. Unknown replies from a
running instance fail closed. Logind privacy and the pending-lock marker prevent
the menu opening while locking, locked or in unknown state; a privacy change
closes an open menu.

Lock and suspend run immediately. Logout, restart and shutdown require holding
their button or shortcut for 900 ms. Releasing early, closing the menu or losing
focus cancels the hold. Shortcuts are L, S, O, R and P; Escape dismisses the menu,
and arrow keys select actions.

Actions appear in five balanced cards: Lock, Log out, Suspend, Restart and Shut
down. Narrow windows wrap into three or two columns and scroll vertically to
reveal keyboard-focused actions. Each tile keeps its vector icon, name, shortcut
and hold progress ring.

Root `settings.json` owns appearance and provider argument arrays. Empty arrays
disable actions. A fresh full installation uses `astral-lock` for lock, suspend,
logout, reboot and poweroff; existing provider arrays, including empty ones, are
preserved on upgrades. The bar and menu use `common/SessionService.qml`.
Providers receive separate literal arguments. Suspend requires a lock provider
and successful logind confirmation; the built-in controller also verifies the
compositor. Failed actions report an error.

`common/Overlays.qml` dismisses peers when opening the menu. It never cancels
Polkit authentication. Global `astral-launcher close-active` checks Polkit before
the session menu and other overlays.

## Replacement and checks

Replace the `astral-session` registry path with a QML entry. Public commands
require a `session` IPC handler with `state()` returning `loading` or `ready`,
`toggle(monitor)` returning `ok` or `blocked`, `close()` returning `ok`, and
`closeActive()` returning `closed` or `inactive`. An unknown reply never
authorizes closing an application.

```bash
bash tests/session/run.sh
bash scripts/test-quickshell.sh session
```

Tests use fictional power tools and isolated Astral XDG storage. The preview
shows disabled action tiles in an ordinary window and never calls power tools.
Verify real focus, monitor removal, PAM, logout and suspend manually on CachyOS.

Install either module with `bash scripts/manage-configs.sh apply quickshell
--module astral-lock` or `--module astral-session`. External `--source` entries
need only QML. Partial installation supplies the root common files once, and
does not enable providers for an absent locker.

The action grid wraps to three or two columns on small screens. Arrow navigation reveals the focused tile vertically. Action symbols use vector paths; hold confirmation keeps its progress ring.
