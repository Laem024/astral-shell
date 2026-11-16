# Lock and idle

The active module lives in `config/quickshell/astral-lock/`. Root `lock.qml`
starts its PAM controller and Wayland session-lock surfaces. Root `idle.qml`
starts native Quickshell idle notifications and the logind sleep guard.
Neither module has a shell backend or requires a JavaScript runtime package.

## Commands and settings

After installation, use `astral-lock` or `astral-lock lock`. A successful request
means the compositor reported a secure lock. `astral-lock privacy` reports
`idle` only when logind reports unlocked and no lock is pending. Unknown state
and a failed locker remain blocked.

Root `settings.json` owns the shared theme, `profile.name`, `profile.image`,
`lockScreen.showProfile`, `lockScreen.showMusic`, and:

```json
"idle": {
  "enabled": true,
  "lockSeconds": 300,
  "screenOffSeconds": 600,
  "suspendSeconds": 900
}
```

Timeouts are ordered positive whole seconds, at most 86400. Disable automatic
idle actions with `idle.enabled=false`. The independent sleep guard still handles
logind Lock and PrepareForSleep events. Disable the `astral-idle` registry entry
to stop the entire worker. The locker itself has `autostart=false`; starting the
shell must never lock the desktop automatically.

`astral-lock suspend` confirms the lock before calling systemd with inhibitor
checking enabled. `auto-suspend` additionally checks caffeine, effective idle
inhibitors, every MPRIS player and the idle worker, including a second check
after securing the lock. Unknown media state blocks automatic suspend.
`auto-lock` and `auto-dpms` respect caffeine and idle inhibitors.
`idle` starts the idle worker and begins its suspend check; `activity` cancels
that check. Manual lock and suspend remain usable with caffeine enabled.
Caffeine inhibits idle; normal lid behavior stays with logind.

The sleep guard holds a logind delay inhibitor until the compositor confirms
the lock, then rearms it after resume. Logind limits delay inhibitors; check
real lid/suspend behavior on the target machine. A failed locker cannot keep a
delay inhibitor effective beyond logind's configured limit.

## Authentication and privacy

PAM uses the real process user and the existing `login` service. Responses are
transient call arguments and cleared on flow transitions. PAM failure, lockout,
service error and an unconfirmed compositor never unlock the session.
The authenticated exit animation completes before releasing the compositor lock.
IPC exposes only `lock()` and `state()`; no unlock method exists.

`common/SessionHint.qml` creates a pending marker under
`$XDG_RUNTIME_DIR/astral-shell/`, publishes logind's locked hint after compositor
confirmation and clears the marker only after authenticated unlock. A failed
locker leaves privacy closed. Recover by successfully locking and authenticating
again. Shared privacy uses both the marker and
[logind's LockedHint](https://www.freedesktop.org/software/systemd/man/latest/org.freedesktop.login1.html).
Theme files and preferences stay at the root; user/media services live in
`common/` and are shared with the bar.

## Replacement and validation

Replace the `astral-lock` registry path with any QML entry. Public lock/suspend
commands additionally require `lock.state()` returning `secure` or `locking`.
The replacement must preserve authenticated unlock and logind privacy. The idle
worker is independently replaceable through `astral-idle`.

```bash
bash tests/lock/run.sh
bash scripts/test-quickshell.sh lock
```

The tests substitute PAM, lock surfaces, idle notifications and system tools in
a disposable Astral XDG tree. They cover authentication failures, retry,
password clearing, IPC restrictions, concurrent startup, compositor confirmation,
media/inhibitor failures, cancellation and sleep-delay rearming. The preview is
an ordinary window with simulated authentication; type `demo` to demonstrate its
exit animation. It never registers a session lock or invokes PAM.
