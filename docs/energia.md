# Power and session integration

`astral-bar/data/PowerService.qml` owns power operations and status. `PowerData.qml` uses Quickshell's UPower profile setter. The service independently reads the daemon's `ActiveProfile` through `busctl` before showing a requested profile as applied. Unsupported profiles are disabled, and failed verification is reported.

## Session providers

Root `settings.json` contains optional argument arrays for `lock`, `suspend`, `logout`, `reboot`, and `poweroff`. Empty arrays hide those actions. Logout, reboot and poweroff require confirmation. Suspend requires a lock provider and a confirmed logind locked hint before it invokes the suspend provider. Unknown lock state blocks sensitive bar content and capture. See [provider contracts](quickshell.md).

The built-in Astral locker confirms compositor security and publishes logind privacy. Root settings preserve external providers and intentional empty arrays; configure providers when upgrading an earlier installation. Astral Polkit starts with `astral-shell` for graphical `pkexec` prompts; disable any other authentication agent first. The old modules remain reference only.

## Caffeine

`common/Caffeine.qml` replaces the shell helper. The user service runs its installed copy at `~/.local/lib/astral-shell/common/Caffeine.qml`. The preference remains `$XDG_STATE_HOME/astral-shell/caffeine`, or `~/.local/state/astral-shell/caffeine`. FileView publishes preference changes atomically.

The worker starts `systemd-inhibit --what=idle --mode=block` and independently verifies its inhibitor PID through logind's `ListInhibitors`. The bar distinguishes the saved preference, service availability, and effective inhibitor state. A preference change remains pending until confirmation or timeout. Failed service startup or verification displays an error while retaining the preference.

Caffeine respects logind's lid and suspend policy. It does not request a lid-switch inhibitor. The unit belongs to the graphical session; stopping it releases its inhibitor.

## Charge limit

The privileged scripts in `system/power/` remain system administration tools. `scripts/install-power.sh` installs root-owned copies, policy, udev and resume integration, and separately installs the caffeine worker/common dependencies and user unit. `--stage ABSOLUTE_DIRECTORY` exercises copying in a temporary destination.

The bar checks that `/usr/local/libexec/astral-charge-limit` is a regular root-owned file without group/other write permission. Status comes from that helper. Apply/disable use `pkexec` with separate arguments. The helper still validates thresholds, authenticates, reads back controller changes, and preserves/rolls back saved policy on failure. Driver and MSI setup remain documented in [MSI EC](msi-ec.md).

```bash
systemctl --user status astral-caffeine.service
journalctl --user -u astral-caffeine.service
/usr/local/libexec/astral-charge-limit status
bash tests/power/charge.sh
bash tests/quickshell/run.sh
```

Check real profile switching, authentication cancellation, unsupported hardware, service failure/recovery, idle inhibition and lid behavior on CachyOS. Restore the original charge policy after manual hardware tests.
