# Polkit authentication

`config/quickshell/astral-polkit/` owns the native Quickshell PolkitAgent,
authentication service, dialog and reusable visual content. The root entry is
`config/quickshell/polkit.qml`; shared settings and theme come from `common/`.
Only dialog dimensions are local. `quickshell-old/` remains reference only.

The default registry enables and autostarts `astral-polkit` with `astral-shell`.
Run one authentication agent per session. Registration failures produce a
diagnostic and never stop external agents. Disable another agent through its
own session configuration before enabling Astral's agent.

```bash
astral-polkit             # Ensure registration; daemon is the default
astral-polkit status      # ready, active, loading, or inactive (exit 1)
astral-polkit cancel      # Cancel the current request
astral-polkit restart     # Replace only this configured instance
bash tests/polkit/run.sh
bash scripts/test-quickshell.sh polkit
```

The public dispatcher passes literal arguments to `polkit-control.qml`. This
QML controller uses `common/Command.qml`, a private startup lock beneath
`$XDG_RUNTIME_DIR/astral-shell/`, bounded commands, four-second registration
windows and at most three starts. Unknown instance replies fail closed.
The native agent retains `/org/astral/shell/PolkitAgent` across reloads.

The `polkit` IPC target retains `state`, `registered`, `active`, `action`, and
`cancel`. `state` retains its `ready`/`loading` replies; public `status` also
checks `active`. `closeActive` cancels a pending request and returns `closed`, or returns
`inactive`. Global launcher close checks Polkit before other overlays and the
active application. Opening a panel does not cancel authentication.

The dialog supports identity selection, retries, action details, supplementary
errors and visible or hidden responses. It chooses the focused monitor, falling
back to the first available monitor. Logind's locked hint controls privacy:
blocked or unknown state immediately destroys the surface, clears its response,
and prevents submission. A pending request may reappear after confirmed unlock.
Responses also clear on submit, cancel, identity change and completion.

`PolkitPreview.qml` shares the content inside an ordinary window with a simulated
flow. Both the dedicated preview and `all` register no authentication agent.
Tests isolate XDG storage and simulate registration, concurrency, failed or late
registration, deadlines, restart, IPC and authentication flows. They install no
dependencies and do not modify active configuration. On CachyOS, manually verify
real authentication, exclusive keyboard focus, locking during a request, and
monitor changes with one agent active.

Full, partial and named installation use the usual configuration manager;
`--module astral-polkit --source /path/to/main.qml` installs an external entry.
Existing disabled flags, custom entry paths and shared preferences are retained.
See [installation and module registration](quickshell.md).
