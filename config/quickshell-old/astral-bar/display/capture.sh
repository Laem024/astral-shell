#!/usr/bin/env bash
# Private recording supervisor. stdin EOF and TERM both finalize our own child.
set -euo pipefail
umask 077
kind=${1:?}; mode=${2:?}; monitor=${3:-}; audio=${4:-none}
if [[ $kind == record && $mode != monitor && $mode != region ]]; then
  echo 'Recording supports only monitor or region.' >&2
  exit 2
fi
need() { command -v "$1" >/dev/null || { printf 'Missing dependency: %s\n' "$1" >&2; exit 1; }; }
# Quickshell may SIGKILL its direct child on destruction. A separate session
# owns cleanup and observes stdin EOF even if the tracked launcher is killed.
if [[ $kind == record && ${ASTRAL_CAPTURE_SUPERVISOR:-0} != 1 ]]; then
  need setsid
  supervisor=
  forward_stop() {
    trap '' TERM INT HUP
    kill -TERM "$supervisor" 2>/dev/null || true
    wait "$supervisor" 2>/dev/null || true
    exit 143
  }
  trap forward_stop TERM INT HUP
  env --default-signal=INT,TERM,HUP,PIPE setsid env ASTRAL_CAPTURE_SUPERVISOR=1 bash "$0" "$@" <&0 &
  supervisor=$!
  result=0; wait "$supervisor" || result=$?
  exit "$result"
fi
for tool in jq hyprctl mktemp; do need "$tool"; done
[[ $kind == shot || $kind == record || $kind == allocate || $kind == verify ]] || exit 2
[[ $audio == none || $audio == system || $audio == microphone || $audio == both ]] || exit 2
if [[ $kind == verify ]]; then [[ -s $monitor ]] || exit 1; printf 'saved\t%s\n' "$monitor"; exit; fi
if [[ $kind == record ]]; then
  : "${XDG_RUNTIME_DIR:?}"
  exec 9>"$XDG_RUNTIME_DIR/astral-recording-${WAYLAND_DISPLAY:-wayland-0}.lock"
  flock -n 9 || { echo 'A recording is already running.' >&2; exit 1; }
fi
folder=$HOME/Pictures/Screenshots; extension=png
if [[ $kind == record ]]; then folder=$HOME/Videos/ScreenRecordings; extension=mkv; fi
mkdir -p -- "$folder"
file=$(mktemp "$folder/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.$extension")
child=; selection=; selector_log=; recorder_log=; modules=(); completed=false
profile_changed=false; profile_card=; profile_original=; autoswitch_was=false; bt_input=false
cleanup() {
  trap '' TERM INT HUP PIPE
  if [[ -n $child ]]; then
    signal=INT; [[ -z $selection ]] || signal=TERM
    kill -"$signal" "$child" 2>/dev/null || true
    if wait "$child" 2>/dev/null && [[ $kind == record && -z $selection && -s $file ]]; then completed=true; fi
  fi
  for ((i=${#modules[@]}-1; i>=0; i--)); do pactl unload-module "${modules[i]}" >/dev/null 2>&1 || true; done
  if [[ $profile_changed == true && -n $profile_card && -n $profile_original ]]; then
    pactl set-card-profile "$profile_card" "$profile_original" >/dev/null 2>&1 || true
  fi
  # WirePlumber must regain its profile policy only after our streams are gone.
  if [[ $autoswitch_was == true ]] && command -v wpctl >/dev/null 2>&1; then
    wpctl settings bluetooth.autoswitch-to-headset-profile true >/dev/null 2>&1 || true
  fi
  [[ -z $selection ]] || rm -f -- "$selection"
  [[ -z $selector_log ]] || rm -f -- "$selector_log"
  [[ -z $recorder_log ]] || rm -f -- "$recorder_log"
  if [[ $completed != true ]]; then
    if [[ -s $file ]]; then printf 'Incomplete recording: %s\n' "$file" >&2; else rm -f -- "$file"; fi
  fi
}
trap cleanup EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
trap 'exit 0' PIPE
if [[ $kind == allocate ]]; then completed=true; printf 'allocated\t%s\n' "$file"; exit; fi
geometry=
if [[ $mode == region ]]; then
  need slurp
  printf 'selecting\n'
  selection=$(mktemp)
  selector_log=$(mktemp)
  # Never let slurp read the supervisor's still-open control pipe as rectangle input.
  slurp -d -f '%x,%y %wx%h' </dev/null > "$selection" 2> "$selector_log" &
  child=$!
  selection_result=0; wait "$child" || selection_result=$?
  child=
  if (( selection_result != 0 )); then
    if [[ -s $selector_log ]]; then cat "$selector_log" >&2; exit 1; fi
    printf 'cancelled\n'; exit 0
  fi
  geometry=$(cat "$selection"); rm -f -- "$selection"; selection=
  [[ $geometry =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]] || { echo 'Invalid region returned by selector.' >&2; exit 1; }
  x=${BASH_REMATCH[1]}; y=${BASH_REMATCH[2]}; w=${BASH_REMATCH[3]}; h=${BASH_REMATCH[4]}
  (( w > 0 && h > 0 )) || { printf 'cancelled\n'; exit 0; }
  if [[ $kind == record ]]; then
    # Resolve the output from the selected region, including scale and rotation.
    # Screenshots can span displays; a recording must fit one output.
    monitors=$(hyprctl -j monitors)
    monitor=$(jq -er --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" '
      [.[] | . + {lw: ((if .transform % 2 == 1 then .height else .width end)/.scale),
                         lh: ((if .transform % 2 == 1 then .width else .height end)/.scale)}
       | select($x >= .x and $y >= .y and $x+$w <= .x+.lw and $y+$h <= .y+.lh)]
      | if length == 1 then .[0].name else empty end' <<< "$monitors") || {
      echo 'Keep the recording region inside a single display.' >&2; exit 1;
    }
  fi
  [[ $kind != record ]] || printf 'output\t%s\n' "$monitor"
  # Give the compositor a frame to remove the selection overlay.
  sleep 0.12
elif [[ $mode == monitor ]]; then
  monitors=$(hyprctl -j monitors)
  jq -e --arg name "$monitor" '.[] | select(.name == $name)' <<< "$monitors" >/dev/null || { echo 'Monitor disconnected.' >&2; exit 1; }
elif [[ $mode != window ]]; then exit 2
fi
if [[ $kind == shot ]]; then
  need grim
  if [[ -n $geometry ]]; then args=(-g "$geometry"); else args=(-o "$monitor"); fi
  grim "${args[@]}" "$file"
  [[ -s $file ]] || { echo 'Screenshot is empty.' >&2; exit 1; }
  completed=true; printf 'saved\t%s\n' "$file"; exit
fi
need setsid
need wf-recorder

card_profile() {
  pactl list cards 2>/dev/null | awk -v card="$1" '
    /^[[:space:]]*Name: / { name = $2 }
    name == card && /^[[:space:]]*Active Profile: / { print $3; exit }
  '
}
set_card_profile() {
  local card=$1; shift
  local profile
  for profile in "$@"; do
    if pactl set-card-profile "$card" "$profile" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}
bt_source_card() {
  [[ $1 == bluez_input.* ]] || return 1
  local mac=${1#bluez_input.}
  printf 'bluez_card.%s\n' "${mac//:/_}"
}
bt_sink_card() {
  [[ $1 == bluez_output.* ]] || return 1
  local name=${1#bluez_output.}
  printf 'bluez_card.%s\n' "${name%.*}"
}
source_is_used() {
  local source=$1 source_index
  source_index=$(pactl list short sources 2>/dev/null | awk -v source="$source" '$2 == source { print $1; exit }')
  [[ -n $source_index ]] || return 1
  pactl list short source-outputs 2>/dev/null | awk -v source_index="$source_index" '$2 == source_index { found = 1 } END { exit !found }'
}
wait_for_node() {
  local name=$1 kind=$2 i
  for ((i=0; i<30; i++)); do
    pactl list short "$kind" 2>/dev/null | awk -v name="$name" '$2 == name { found = 1 } END { exit !found }' && return 0
    sleep 0.1
  done
  return 1
}
bluez_transport_error() {
  command -v pw-dump >/dev/null 2>&1 || return 1
  pw-dump 2>/dev/null | jq -e '
    [.[] | select(.type == "PipeWire:Interface:Node")
         | select((.info.props["node.name"] // "") | test("^bluez_(input|output)"))
         | select(.info.state == "error")] | length > 0' >/dev/null 2>&1
}
# A Bluetooth microphone only exists in the HFP profile. Switching later would
# recreate the headset nodes and break the loopbacks, so switch first and keep
# WirePlumber from restoring A2DP while the recording is active.
pin_bluetooth_microphone() {
  local source=$1 card current
  card=$(bt_source_card "$source") || return 0
  current=$(card_profile "$card")
  [[ -n $current ]] || { echo 'The Bluetooth headset card is unavailable.' >&2; return 1; }
  profile_changed=true; profile_card=$card; profile_original=$current
  if command -v wpctl >/dev/null 2>&1 &&
     [[ $(wpctl settings bluetooth.autoswitch-to-headset-profile 2>/dev/null | awk '{print $2}') == true ]]; then
    if wpctl settings bluetooth.autoswitch-to-headset-profile false >/dev/null 2>&1; then
      autoswitch_was=true
    fi
  fi
  bt_input=true
  if [[ $current != headset-head-unit* ]]; then
    set_card_profile "$card" headset-head-unit headset-head-unit-cvsd || {
      echo 'The Bluetooth headset does not expose a microphone profile.' >&2
      return 1
    }
  fi
  wait_for_node "$source" sources || {
    echo 'The Bluetooth headset microphone did not appear.' >&2
    return 1
  }
  return 0
}
# HFP is mono and low quality, and a broken HFP transport also silences
# playback. When the microphone is not the headset, prefer its A2DP output.
use_bluetooth_playback() {
  local sink=$1 card current source mac
  [[ $sink == bluez_output.* ]] || return 0
  card=$(bt_sink_card "$sink") || return 0
  current=$(card_profile "$card")
  [[ -n $current && $current != a2dp-sink* ]] || return 0
  mac=${card#bluez_card.}
  source="bluez_input.${mac//_/:}"
  # Never interrupt another application that is already recording from it.
  if source_is_used "$source"; then
    echo 'The Bluetooth headset microphone is in use; keeping its current profile.' >&2
    return 0
  fi
  set_card_profile "$card" a2dp-sink a2dp-sink-sbc a2dp-sink-sbc_xq || return 0
  wait_for_node "$sink" sinks || true
  return 0
}

args=(wf-recorder -y -o "$monitor" -c libx264 -C aac -f "$file")
[[ -z $geometry ]] || args+=(-g "$geometry")
if [[ $audio != none ]]; then
  need pactl
  case $audio in
    system)
      sink=$(pactl get-default-sink)
      use_bluetooth_playback "$sink"
      sink=$(pactl get-default-sink)
      source=$sink.monitor;;
    microphone|both)
      # PulseAudio compatibility exposes sink monitors as sources. Using one as
      # a microphone would silently record only system audio.
      source=$(pactl get-default-source) || { echo 'No default microphone is available.' >&2; exit 1; }
      if [[ $source == *.monitor ]]; then
        echo 'The default source is a monitor. Select a microphone in the Sound panel and try again.' >&2
        exit 1
      fi
      # A muted device captures digital silence: warn before recording a video
      # that would only contain system audio.
      if pactl get-source-mute "$source" | grep -q 'yes'; then
        echo 'The microphone is muted. Unmute it or choose another audio option.' >&2
        exit 1
      fi
      if [[ $source == bluez_input.* ]]; then
        pin_bluetooth_microphone "$source" || exit 1
      else
        use_bluetooth_playback "$(pactl get-default-sink)"
      fi
      if [[ $audio == both ]]; then
        sink=$(pactl get-default-sink)
        if [[ $bt_input == true ]]; then
          wait_for_node "$sink" sinks || { echo 'The Bluetooth headset output did not appear.' >&2; exit 1; }
        fi
        mix=astral_recording_$$
        modules+=("$(pactl load-module module-null-sink sink_name="$mix")")
        modules+=("$(pactl load-module module-loopback source="$source" sink="$mix" latency_msec=30 source_dont_move=true sink_dont_move=true)")
        modules+=("$(pactl load-module module-loopback source="$sink.monitor" sink="$mix" latency_msec=30 source_dont_move=true sink_dont_move=true)")
        source=$mix.monitor
      fi;;
  esac
  args+=(--audio="$source")
fi
printf 'preparing\n'
recorder_log=$(mktemp)
# setsid resets inherited asynchronous SIGINT handling and isolates the recorder.
started_at=$(date +%s%3N)
env --default-signal=INT setsid "${args[@]}" 9>&- > /dev/null 2> "$recorder_log" &
child=$!
# A stale SCO transport yields digital silence and is only visible after a
# capture stream starts. Fail early instead of saving a video without the mic.
if [[ $bt_input == true ]]; then
  sleep 0.7
  if bluez_transport_error; then
    echo 'Bluetooth headset microphone transport failed (HFP/SCO). Reconnect the headset and try again.' >&2
    kill -INT "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
    child=; rm -f -- "$file"
    exit 1
  fi
fi
# Encoders buffer output; file size is not a recording-start signal.
printf 'recording\t%s\n' "$started_at"
stopped=false
while kill -0 "$child" 2>/dev/null; do
  if read -r -t 0.2 instruction; then
    if [[ $instruction == stop ]]; then stopped=true; break; fi
  else
    result=$?
    if (( result == 1 )); then stopped=true; break; fi
  fi
done
if [[ $stopped == true && ! -s $file ]]; then
  # A stop may arrive before the child installs its signal handlers.
  for ((attempt=0; attempt<20; attempt++)); do
    [[ ! -s $file ]] && kill -0 "$child" 2>/dev/null || break
    sleep 0.05
  done
fi
if [[ $stopped == true ]]; then printf 'finalizing\n'; kill -INT "$child" 2>/dev/null || true; fi
result=0
wait "$child" || result=$?
child=
cat "$recorder_log" >&2
if (( result != 0 )) || [[ ! -s $file ]]; then
  echo 'Recording failed (audio or encoder); any nonempty file is incomplete.' >&2; exit 1
fi
completed=true
printf 'saved\t%s\n' "$file"
