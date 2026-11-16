#!/usr/bin/env bash
set -euo pipefail
# Sysfs reads are cheap and also observe brightness keys outside Quickshell.
# Keep DDC/CI discovery out of this fast path.
if [[ ${1:-} == watch ]]; then
  shopt -s nullglob
  declare -A previous=()
  while :; do
    for backlight in "${ASTRAL_BACKLIGHT_ROOT:-/sys/class/backlight}"/*; do
      IFS= read -r current 2>/dev/null < "$backlight/brightness" || continue
      IFS= read -r maximum 2>/dev/null < "$backlight/max_brightness" || continue
      [[ $current =~ ^[0-9]+$ && $maximum =~ ^[0-9]+$ ]] && (( maximum > 0 )) || continue
      percent=$((current * 100 / maximum))
      device=${backlight##*/}
      if [[ ${previous[$device]:-} != "$percent" ]]; then
        previous[$device]=$percent
        printf 'backlight\t%s\t%s\n' "$device" "$percent"
      fi
    done
    sleep 0.1
  done
fi
# Map DRM connector -> I2C bus; never guess by display enumeration order.
monitors=$(hyprctl -j monitors)
mapfile -t internals < <(jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)-")) | .name' <<< "$monitors")
shopt -s nullglob
backlights=("${ASTRAL_BACKLIGHT_ROOT:-/sys/class/backlight}"/*)
resolve() {
  device=; type=; reason='No compatible backlight or DDC/CI device.'
  if [[ $1 =~ ^(eDP|LVDS|DSI)- && ${#internals[@]} == 1 && ${#backlights[@]} == 1 ]]; then
    type=backlight; device=${backlights[0]##*/}
  elif [[ ! $1 =~ ^(eDP|LVDS|DSI)- ]]; then
    connectors=("${ASTRAL_DRM_ROOT:-/sys/class/drm}"/card*-"$1")
    if (( ${#connectors[@]} == 1 )) && [[ -e ${connectors[0]}/ddc ]]; then
      bus_path=$(readlink -f -- "${connectors[0]}/ddc")
      bus_name=${bus_path##*/}
      if [[ $bus_name =~ ^i2c-([0-9]+)$ ]]; then type=ddc; device=${BASH_REMATCH[1]}; fi
    fi
  else reason='Ambiguous backlight mapping.'; fi
}
read_value() {
  if [[ $type == backlight ]]; then
    current=$(brightnessctl -d "$device" get); maximum=$(brightnessctl -d "$device" max)
  else
    values=$(ddcutil --bus "$device" getvcp 10 --terse)
    read -r _ _ _ current maximum <<< "$values"
  fi
  [[ $current =~ ^[0-9]+$ && $maximum =~ ^[0-9]+$ ]] && (( maximum > 0 )) || return 1
  percent=$((current * 100 / maximum))
}
if [[ ${1:-list} == set ]]; then
  name=${2:?}; value=${3:?}
  [[ $value =~ ^[0-9]+$ ]] && ((value <= 100)) || exit 2
  jq -e --arg n "$name" '.[] | select(.name == $n)' <<< "$monitors" >/dev/null
  resolve "$name"; [[ -n $device ]] || { echo "$reason" >&2; exit 1; }
  exec 9>"${XDG_RUNTIME_DIR:?}/astral-brightness-$type-$device.lock"
  flock 9
  if [[ $type == backlight ]]; then brightnessctl -d "$device" set "$value%" >/dev/null
  else ddcutil --bus "$device" setvcp 10 "$value" >/dev/null; fi
  read_value
  printf '%s\n' "$percent"
else
  while IFS= read -r name; do
    resolve "$name"; percent=0; available=false
    if [[ -n $device ]] && read_value 2>/dev/null; then available=true; reason='';
    elif [[ -n $device ]]; then reason='Cannot read brightness: check dependency, permissions and DDC/CI.'; fi
    jq -cn --arg name "$name" --arg device "$device" --arg backend "$type" --arg reason "$reason" --argjson available "$available" --argjson percent "$percent" '{name:$name,device:$device,backend:$backend,reason:$reason,available:$available,percent:$percent}'
  done < <(jq -r '.[].name' <<< "$monitors") | jq -s .
fi
