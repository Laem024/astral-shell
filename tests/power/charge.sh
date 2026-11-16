#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch power)
trap 'chmod -R u+w "$runtime"; rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/sys/BAT0" "$runtime/bin" "$runtime/lock"
printf '#!/usr/bin/env bash\nexit 1\n' > "$runtime/bin/modprobe"
chmod +x "$runtime/bin/modprobe"
# Only this disposable copy can access fake sysfs and bypass the root check.
sed -e "s|sys=/sys/class/power_supply|sys=$runtime/sys|" \
  -e "s|store=/var/lib/astral-shell|store=$runtime/store|" \
  -e "s|/run/lock/astral-charge-limit.lock|$runtime/lock/action|" \
  -e 's/\[\[ $EUID -eq 0 \]\]/true/' \
  -e "s|export PATH=/usr/bin:/usr/sbin|export PATH=$runtime/bin:/usr/bin:/usr/sbin|" \
  system/power/astral-charge-limit > "$runtime/helper"
chmod +x "$runtime/helper"
helper() { bash "$runtime/helper" "$@"; }
if helper status 2>/dev/null; then exit 1; fi
printf 'Battery\n' > "$runtime/sys/BAT0/type"
printf '100\n' > "$runtime/sys/BAT0/charge_control_end_threshold"
helper apply BAT0 80
[[ $(cat "$runtime/store/charge-limit") == 'BAT0 80' ]]
[[ $(helper status) == $'BAT0\n80\nBAT0\n80' ]]
for invalid in 0 101 1.5 080 '-1' '80;id'; do
  if helper apply BAT0 "$invalid" 2>/dev/null; then exit 1; fi
done
if helper apply ../../etc/passwd 80 2>/dev/null; then exit 1; fi
# Controller rejection/rounding is detected by readback and rolled back.
cat > "$runtime/bin/cat" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == */charge_control_end_threshold && $(/usr/bin/cat "$1") == 77 ]]; then printf '76\n'; else exec /usr/bin/cat "$@"; fi
MOCK
chmod +x "$runtime/bin/cat"
if helper apply BAT0 77 2>/dev/null; then exit 1; fi
[[ $(cat "$runtime/sys/BAT0/charge_control_end_threshold") == 80 ]]
[[ $(cat "$runtime/store/charge-limit") == 'BAT0 80' ]]
if [[ $EUID != 0 ]]; then
  chmod 444 "$runtime/sys/BAT0/charge_control_end_threshold"
  if helper apply BAT0 85 2>/dev/null; then exit 1; fi
  chmod 644 "$runtime/sys/BAT0/charge_control_end_threshold"
fi
# Boot, resume and a new battery event all run the same reapply command.
for trigger in boot resume battery; do
  printf '100\n' > "$runtime/sys/BAT0/charge_control_end_threshold"
  helper reapply
  [[ $(cat "$runtime/sys/BAT0/charge_control_end_threshold") == 80 ]]
done
mv "$runtime/sys/BAT0" "$runtime/sys/absent"
if helper reapply 2>/dev/null; then exit 1; fi
mv "$runtime/sys/absent" "$runtime/sys/BAT0"
helper disable BAT0
[[ $(cat "$runtime/sys/BAT0/charge_control_end_threshold") == 100 && ! -f $runtime/store/charge-limit ]]
helper reapply
if helper arbitrary-command 2>/dev/null; then exit 1; fi
# Client-side authentication cancellation is covered by the QML service checks.
bash scripts/install-power.sh --stage "$runtime/stage"
[[ $(stat -c %a "$runtime/stage/usr/local/libexec/astral-charge-limit") == 755 ]]
cmp system/power/astral-charge-limit "$runtime/stage/usr/local/libexec/astral-charge-limit"
cmp config/quickshell/common/Caffeine.qml "$runtime/stage/user/.local/lib/astral-shell/common/Caffeine.qml"
# Reinstalling changed files backs them up; matching files remain untouched.
printf 'old helper\n' > "$runtime/stage/usr/local/libexec/astral-charge-limit"
bash scripts/install-power.sh --stage "$runtime/stage" > "$runtime/install-log"
rg -q 'Backup:' "$runtime/install-log"
backup=("$runtime/stage/usr/local/libexec/astral-charge-limit.backup-"*)
[[ $(cat "${backup[0]}") == 'old helper' ]]
cmp system/power/astral-charge-limit "$runtime/stage/usr/local/libexec/astral-charge-limit"
bash scripts/install-power.sh --stage "$runtime/stage" > "$runtime/install-log"
[[ ! -s $runtime/install-log ]]
printf 'CHARGE_PASS\n'
