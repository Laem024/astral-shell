#!/usr/bin/env bash
set -euo pipefail
umask 077

monitor_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
workspace=resources
window_class=astral-monitor
window_title="Astral Monitor"
btop_config=$monitor_dir/btop.conf
btop_themes=$monitor_dir/themes
btop_bin=${ASTRAL_MONITOR_BTOP:-btop}
terminal_bin=${ASTRAL_MONITOR_TERMINAL:-kitty}

child_pid=''
cleanup() {
  [[ -n $child_pid ]] || return 0
  kill -0 "$child_pid" 2>/dev/null || return 0
  kill "$child_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

help() {
  printf 'Usage: astral-monitor [toggle|open|close]\n' >&2
  exit 2
}

fail() {
  printf 'astral-monitor: %s\n' "$*" >&2
  hyprctl notify 3 4000 0 "astral-monitor: $*" >/dev/null 2>&1 || true
  exit 1
}

# Match shared Quickshell privacy: only an explicit unlocked logind hint opens.
locked() {
  local hint
  [[ -n ${XDG_RUNTIME_DIR:-} && $XDG_RUNTIME_DIR == /* && -d $XDG_RUNTIME_DIR
    && ! -L $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR
    && $(stat -c %a -- "$XDG_RUNTIME_DIR") == 700 ]] || return 0
  [[ ! -e $XDG_RUNTIME_DIR/astral-shell/lock-pending && ! -L $XDG_RUNTIME_DIR/astral-shell/lock-pending ]] || return 0
  hint=$(timeout 2 loginctl show-session "${XDG_SESSION_ID:-auto}" --property=LockedHint --value 2>/dev/null) || return 0
  [[ $hint != no ]]
}

special_open() {
  hyprctl monitors -j 2>/dev/null \
    | jq -e --arg name "special:$workspace" \
        'any(.[]; .focused == true and .specialWorkspace.name == $name)' >/dev/null 2>&1
}

toggle_special() {
  hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$workspace\")" >/dev/null
}

window_pid() {
  local pid
  pid=$(hyprctl clients -j 2>/dev/null \
    | jq -r --arg class "$window_class" 'first(.[] | select(.class == $class) | .pid) // empty' 2>/dev/null) || return 0
  if [[ $pid =~ ^[0-9]+$ ]]; then printf '%s' "$pid"; fi
  return 0
}

window_on_special() {
  hyprctl clients -j 2>/dev/null \
    | jq -e --arg class "$window_class" --arg ws "special:$workspace" \
        'any(.[]; .class == $class and .workspace.name == $ws)' >/dev/null 2>&1
}

focus_window() {
  hyprctl dispatch "hl.dsp.focus({ window = \"class:$window_class\" })" >/dev/null 2>&1 || true
}

dismiss_panels() {
  astral-bar close-panels 9>&- >/dev/null 2>&1 || true
  astral-launcher close 9>&- >/dev/null 2>&1 || true
  astral-wallpaper close 9>&- >/dev/null 2>&1 || true
  astral-clipboard close 9>&- >/dev/null 2>&1 || true
  astral-session close 9>&- >/dev/null 2>&1 || true
  astral-shortcuts close 9>&- >/dev/null 2>&1 || true
}

launch() {
  local attempt pid
  locked && return 0
  dismiss_panels
  locked && return 0
  "$terminal_bin" --class "$window_class" --title "$window_title" \
    --single-instance=no --override background_opacity=1.0 \
    -e "$btop_bin" -c "$btop_config" --themes-dir "$btop_themes" 9>&- &
  child_pid=$!
  pid=''
  for ((attempt = 0; attempt < 60; attempt++)); do
    pid=$(window_pid)
    [[ -n $pid ]] && break
    if ! kill -0 "$child_pid" 2>/dev/null; then
      wait "$child_pid" 2>/dev/null || true
      child_pid=''
      fail "The terminal exited before creating the monitor window."
    fi
    sleep 0.05
  done
  if [[ -z $pid ]]; then
    fail "The monitor window did not appear."
  fi

  # The Hyprland window rule normally places the window on the special
  # workspace. Keep a fallback so a missed rule cannot leave the dashboard on
  # the current workspace.
  if locked; then cleanup; return 0; fi
  focus_window
  if ! window_on_special; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:$workspace\", window = \"class:$window_class\" })" >/dev/null 2>&1 || true
  fi
  if ! window_on_special; then
    fail "Could not move the monitor window to special:$workspace."
  fi
  if locked; then cleanup; return 0; fi
  special_open || toggle_special
  focus_window

  # Allow a second invocation to close the dashboard while btop is running.
  exec 9>&-
  wait "$child_pid" || true
  child_pid=''

  # Hyprland can take a moment to remove the client after the terminal exits.
  for ((attempt = 0; attempt < 20; attempt++)); do
    [[ -z $(window_pid) ]] && break
    sleep 0.05
  done
  if [[ -z $(window_pid) ]] && special_open; then
    toggle_special
  fi
}

open_monitor() {
  local pid
  pid=$(window_pid)
  if [[ -z $pid ]]; then
    launch
    return
  fi
  if locked; then cleanup; return 0; fi
  special_open || toggle_special
  focus_window
}

close_monitor() {
  local pid
  pid=$(window_pid)
  if special_open; then toggle_special; fi
  [[ -n $pid ]] || return 0
  kill "$pid" 2>/dev/null || true
}

case ${1:-toggle} in
  toggle|open|close) action=${1:-toggle} ;;
  -h|--help|help) help ;;
  *) help ;;
esac

[[ $action == close ]] || ! locked || exit 0

tools=(hyprctl jq flock)
[[ $action == close ]] || tools+=("$terminal_bin" "$btop_bin")
for tool in "${tools[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required command not found: $tool"
done
[[ -f $btop_config ]] || fail "Missing btop config: $btop_config"
[[ -d $btop_themes ]] || fail "Missing btop theme directory: $btop_themes"
: "${XDG_RUNTIME_DIR:?A user runtime directory is required}"

key=$(printf '%s' "$monitor_dir" | sha256sum)
exec 9>"$XDG_RUNTIME_DIR/astral-monitor-${key%% *}.lock"
flock -w 10 9
[[ $action == close ]] || ! locked || exit 0

case $action in
  toggle)
    pid=$(window_pid)
    if [[ -n $pid ]]; then
      if special_open; then
        toggle_special
        kill "$pid" 2>/dev/null || true
      else
        open_monitor
      fi
    else
      launch
    fi
    ;;
  open) open_monitor ;;
  close) close_monitor ;;
esac
