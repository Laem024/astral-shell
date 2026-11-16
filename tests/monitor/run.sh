#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

source tests/xdg-scratch.sh
runtime=$(astral_test_scratch monitor)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/bin" "$runtime/home/.config" "$runtime/run" "$runtime/state"
chmod 700 "$runtime/run"
export HOME=$runtime/home
export XDG_CONFIG_HOME=$HOME/.config
export XDG_RUNTIME_DIR=$runtime/run
export PATH="$runtime/bin:$PATH"
export ASTRAL_MONITOR_TEST=$runtime/state

cat > "$runtime/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $* == "show-session ${XDG_SESSION_ID:-auto} --property=LockedHint --value" ]] || exit 2
[[ ! -e $ASTRAL_MONITOR_TEST/failed ]] || exit 1
if [[ -e $ASTRAL_MONITOR_TEST/pending-after-query ]]; then
  mkdir -p "$XDG_RUNTIME_DIR/astral-shell"
  touch "$XDG_RUNTIME_DIR/astral-shell/lock-pending"
fi
if [[ -e $ASTRAL_MONITOR_TEST/unknown ]]; then printf 'unknown\n'
elif [[ -e $ASTRAL_MONITOR_TEST/locked ]]; then printf 'yes\n'
else printf 'no\n'; fi
MOCK

cat > "$runtime/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
state=$ASTRAL_MONITOR_TEST
if [[ ${1:-} == monitors ]]; then
  if [[ -e $state/special ]]; then
    printf '[{"focused":true,"specialWorkspace":{"name":"special:resources"}}]\n'
  else
    printf '[{"focused":true,"specialWorkspace":{"name":""}}]\n'
  fi
  exit 0
fi
if [[ ${1:-} == clients ]]; then
  if [[ -f $state/clients.json ]]; then cat "$state/clients.json"; else printf '[]\n'; fi
  exit 0
fi
if [[ ${1:-} == notify ]]; then
  printf '%s\n' "${*:2}" >> "$state/notifications"
  exit 0
fi
if [[ ${1:-} == dispatch ]]; then
  printf '%s\n' "${*:2}" >> "$state/dispatches"
  case ${*:2} in
    *toggle_special*)
      if [[ -e $state/special ]]; then rm -f -- "$state/special"; else : > "$state/special"; fi
      ;;
    *hl.dsp.window.move*)
      if [[ -f $state/clients.json ]]; then
        jq '(.[] | select(.class == "astral-monitor") | .workspace.name) = "special:resources"' \
          "$state/clients.json" > "$state/clients.next"
        mv -- "$state/clients.next" "$state/clients.json"
      fi
      ;;
  esac
  exit 0
fi
printf 'unsupported hyprctl invocation: %s\n' "$*" >&2
exit 1
MOCK

cat > "$runtime/bin/kitty" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
state=$ASTRAL_MONITOR_TEST
printf '%s\n' "$$" >> "$state/kitty"
jq -n --argjson pid "$$" '[{class:"astral-monitor",pid:$pid,workspace:{name:"special:resources"}}]' > "$state/clients.json"
sleep 30 &
sleeper=$!
cleanup() { kill "$sleeper" 2>/dev/null || true; rm -f -- "$state/clients.json"; }
trap cleanup EXIT TERM INT
wait "$sleeper"
MOCK

chmod +x "$runtime/bin/loginctl" "$runtime/bin/hyprctl" "$runtime/bin/kitty"

fail() { printf 'MONITOR_FAIL: %s\n' "$*" >&2; exit 1; }
wait_for() {
  local path=$1 attempt
  for ((attempt = 0; attempt < 100; attempt++)); do
    [[ -e $path ]] && return 0
    sleep 0.05
  done
  return 1
}
wait_gone() {
  local pid=$1 attempt
  for ((attempt = 0; attempt < 100; attempt++)); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.05
  done
  return 1
}

helper=config/monitor/astral-monitor.sh

# A locked session never starts the dashboard.
: > "$runtime/state/locked"
if ! bash "$helper" toggle >/dev/null 2>&1; then fail 'locked toggle failed'; fi
[[ ! -e $runtime/state/kitty ]] || fail 'locked session launched kitty'
rm -f -- "$runtime/state/locked"

for condition in failed unknown; do
  : > "$runtime/state/$condition"
  bash "$helper" open
  [[ ! -e $runtime/state/kitty ]] || fail "$condition privacy launched kitty"
  rm -f -- "$runtime/state/$condition"
done

mkdir -p "$XDG_RUNTIME_DIR/astral-shell"
touch "$XDG_RUNTIME_DIR/astral-shell/lock-pending"
bash "$helper" open
[[ ! -e $runtime/state/kitty ]] || fail 'pending lock launched kitty'
ASTRAL_MONITOR_BTOP=btop-not-installed bash "$helper" close
rm "$XDG_RUNTIME_DIR/astral-shell/lock-pending"
XDG_RUNTIME_DIR= bash "$helper" open
[[ ! -e $runtime/state/kitty ]] || fail 'missing runtime launched kitty'

touch "$runtime/state/pending-after-query"
bash "$helper" open
[[ ! -e $runtime/state/kitty ]] || fail 'pending lock after query launched kitty'
rm "$runtime/state/pending-after-query" "$XDG_RUNTIME_DIR/astral-shell/lock-pending"

# First toggle launches kitty and opens the special workspace.
bash "$helper" toggle > "$runtime/first.log" 2>&1 &
first=$!
wait_for "$runtime/state/special" || fail 'the special workspace did not open'
wait_for "$runtime/state/clients.json" || fail 'the monitor window did not appear'
[[ $(wc -l < "$runtime/state/kitty") == 1 ]] || fail 'kitty was not launched exactly once'
rg -q 'toggle_special' "$runtime/state/dispatches" || fail 'the workspace toggle was not dispatched'
rg -q 'hl.dsp.focus' "$runtime/state/dispatches" || fail 'the monitor window was not focused'

# Second toggle closes the workspace and stops btop.
bash "$helper" toggle >/dev/null 2>&1
wait_gone "$first" || fail 'the first invocation did not exit'
[[ ! -e $runtime/state/special ]] || fail 'the special workspace remained open'
[[ ! -e $runtime/state/clients.json ]] || fail 'the monitor window remained after closing'
[[ $(wc -l < "$runtime/state/kitty") == 1 ]] || fail 'closing launched another kitty'

# Closing from inside btop also closes the now-empty workspace.
rm -f -- "$runtime/state/dispatches"
bash "$helper" open > "$runtime/second.log" 2>&1 &
second=$!
wait_for "$runtime/state/special" || fail 'the workspace did not reopen'
wait_for "$runtime/state/clients.json" || fail 'the second monitor window did not appear'
kitty_pid=$(jq -r '.[0].pid' "$runtime/state/clients.json")
kill "$kitty_pid" 2>/dev/null || true
wait_gone "$second" || fail 'the watcher did not exit after btop closed'
[[ ! -e $runtime/state/special ]] || fail 'btop exit left the workspace open'

# A missing btop reports an error instead of opening an empty workspace.
if ASTRAL_MONITOR_BTOP=btop-not-installed bash "$helper" open > "$runtime/missing.log" 2>&1; then
  fail 'missing btop was accepted'
fi
rg -q 'Required command not found: btop-not-installed' "$runtime/missing.log" || fail 'missing btop error was not clear'
[[ ! -e $runtime/state/special ]] || fail 'missing btop opened the workspace'

# The installer copies the monitor assets and installs its public command.
bash scripts/manage-configs.sh apply monitor > "$runtime/install.log"
installed=$XDG_CONFIG_HOME/astral-monitor
[[ -f $installed/astral-monitor.sh ]] || fail 'monitor script was not installed'
[[ -f $installed/btop.conf ]] || fail 'btop config was not installed'
[[ -f $installed/themes/astral.theme ]] || fail 'btop theme was not installed'
[[ -x $HOME/.local/bin/astral-monitor ]] || fail 'astral-monitor command was not installed'
rg -qF "exec bash $installed/astral-monitor.sh" "$HOME/.local/bin/astral-monitor" || fail 'command points to the wrong path'
bash "$HOME/.local/bin/astral-monitor" --help > "$runtime/help.log" 2>&1 || true
rg -q 'Usage: astral-monitor \[toggle\|open\|close\]' "$runtime/help.log" || fail 'installed command has no help'

printf 'MONITOR_PASS (locking, lazy launch, toggle, cleanup, missing tools, installation)\n'
