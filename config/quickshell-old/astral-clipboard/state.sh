#!/usr/bin/env bash
set -euo pipefail
umask 077

# Personal history lives under the user's state directory, never in the config.
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_root=${ASTRAL_CLIPBOARD_STATE:-${XDG_STATE_HOME:-${HOME:?}/.local/state}/astral-shell/astral-clipboard}
[[ $state_root == /* ]] || state_root=${HOME:?}/.local/state/astral-shell/astral-clipboard
settings_file=${ASTRAL_CLIPBOARD_SETTINGS:-$self_dir/settings.json}
file=$state_root/history.json
images=$state_root/images
lockfile=$state_root/.lock
history_size=50
max_image_bytes=26214400

usage() {
  printf 'Usage: state.sh <read|watch|capture|copy <id>|remove <id>|clear|trim|path>\n' >&2
  exit 2
}

ensure_state() {
  mkdir -p -- "$state_root" "$images"
  chmod 700 -- "$state_root" "$images"
  [[ -f $file ]] || printf '%s\n' '{"version":1,"items":[]}' > "$file"
  chmod 600 -- "$file"
}

read_limits() {
  local value
  history_size=50
  max_image_bytes=26214400
  [[ -r $settings_file ]] || return 0
  value=$(jq -er '.historySize' "$settings_file" 2>/dev/null || true)
  if [[ $value =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 500 )); then history_size=$value; fi
  value=$(jq -er '.maxImageBytes' "$settings_file" 2>/dev/null || true)
  if [[ $value =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 1073741824 )); then max_image_bytes=$value; fi
}

lock_state() {
  ensure_state
  exec 8>"$lockfile"
  flock -w 5 8
}

write_state() {
  local temporary
  temporary=$(mktemp "$state_root/.history.XXXXXX")
  cat > "$temporary"
  mv -f -- "$temporary" "$file"
}

# Remove image files that no history entry references. Caller holds the lock.
gc_images() {
  local path relative
  local -A keep=()
  while IFS= read -r relative; do
    [[ -n $relative ]] && keep[$relative]=1
  done < <(jq -r '.items[] | select(.file != null) | .file' "$file" 2>/dev/null || true)
  for path in "$images"/*; do
    [[ -e $path ]] || continue
    relative="images/${path##*/}"
    [[ -n ${keep[$relative]+present} ]] || rm -f -- "$path"
  done
}

timestamp() { date +%s%3N; }

text_extension() {
  case $1 in
    image/png) printf 'png' ;;
    image/jpeg) printf 'jpg' ;;
    image/webp) printf 'webp' ;;
    image/gif) printf 'gif' ;;
    image/bmp) printf 'bmp' ;;
    image/svg+xml) printf 'svg' ;;
    image/tiff) printf 'tiff' ;;
    image/avif) printf 'avif' ;;
    *) printf 'img' ;;
  esac
}

store_text() {
  local id=$1 mime=$2 text_file=$3 time=$4 temporary
  read_limits
  lock_state
  temporary=$(mktemp "$state_root/.history.XXXXXX")
  jq --arg id "$id" --arg mime "$mime" --rawfile text "$text_file" \
    --argjson time "$time" --argjson limit "$history_size" '
      {version: 1,
       items: ([{id: $id, kind: "text", mime: $mime, text: $text, time: $time}]
               + [.items[] | select(.id != $id)])[:$limit]}
    ' "$file" > "$temporary"
  mv -f -- "$temporary" "$file"
  gc_images
  exec 8>&-
}

store_image() {
  local source=$1 mime=$2 time=$3 size hash extension relative temporary
  read_limits
  size=$(stat -c %s -- "$source")
  if (( size > max_image_bytes )); then
    rm -f -- "$source"
    printf 'Clipboard image ignored: %s bytes exceeds maxImageBytes (%s).\n' "$size" "$max_image_bytes" >&2
    return 0
  fi
  hash=$(sha256sum -- "$source")
  hash=${hash%% *}
  extension=$(text_extension "$mime")
  relative="images/$hash.$extension"
  lock_state
  mkdir -p -- "$images"
  mv -f -- "$source" "$images/${relative##*/}"
  temporary=$(mktemp "$state_root/.history.XXXXXX")
  jq --arg id "$hash" --arg mime "$mime" --arg file "$relative" \
    --argjson bytes "$size" --argjson time "$time" --argjson limit "$history_size" '
      {version: 1,
       items: ([{id: $id, kind: "image", mime: $mime, file: $file, bytes: $bytes, time: $time}]
               + [.items[] | select(.id != $id)])[:$limit]}
    ' "$file" > "$temporary"
  mv -f -- "$temporary" "$file"
  gc_images
  exec 8>&-
}

capture() {
  local incoming types mime extension hash time clean size
  ensure_state
  read_limits
  [[ ${CLIPBOARD_STATE:-} != sensitive ]] || return 0
  incoming=$(mktemp "$state_root/.capture.XXXXXX")
  # The watch command receives the current selection on stdin. Drain it so the
  # watcher never blocks, then ask for the best representation ourselves.
  if [[ -n ${CLIPBOARD_TYPE:-} || ! -t 0 ]]; then
    cat > "$incoming" || true
  fi
  types=$(wl-paste --list-types 2>/dev/null || true)
  if [[ -z $types ]]; then
    rm -f -- "$incoming"
    return 0
  fi
  if grep -Fxq -- 'x-kde-passwordManagerHint' <<< "$types"; then
    rm -f -- "$incoming"
    return 0
  fi
  mime=''
  for candidate in image/png image/jpeg image/webp image/gif image/bmp image/svg+xml image/tiff image/avif; do
    if grep -Fxq -- "$candidate" <<< "$types"; then mime=$candidate; break; fi
  done
  if [[ -z $mime ]]; then
    mime=$(grep -m1 '^image/' <<< "$types" || true)
  fi
  time=$(timestamp)
  if [[ -n $mime ]]; then
    wl-paste --type "$mime" > "$incoming" 2>/dev/null || { rm -f -- "$incoming"; return 0; }
    [[ -s $incoming ]] || { rm -f -- "$incoming"; return 0; }
    store_image "$incoming" "$mime" "$time"
    return 0
  fi
  mime=''
  for candidate in 'text/plain;charset=utf-8' 'text/plain' 'text/uri-list' 'text/html'; do
    if grep -Fxq -- "$candidate" <<< "$types"; then mime=$candidate; break; fi
  done
  if [[ -z $mime ]]; then
    mime=$(grep -m1 '^text/' <<< "$types" || true)
  fi
  [[ -n $mime ]] || { rm -f -- "$incoming"; return 0; }
  wl-paste --type "$mime" > "$incoming" 2>/dev/null || { rm -f -- "$incoming"; return 0; }
  clean=$(mktemp "$state_root/.text.XXXXXX")
  tr -d '\000' < "$incoming" > "$clean"
  rm -f -- "$incoming"
  size=$(stat -c %s -- "$clean")
  if (( size == 0 )); then
    rm -f -- "$clean"
    return 0
  fi
  hash=$(sha256sum -- "$clean")
  hash=${hash%% *}
  store_text "$hash" "$mime" "$clean" "$time"
  rm -f -- "$clean"
}

read_history() {
  ensure_state
  if ! jq -e . "$file" >/dev/null 2>&1; then
    printf 'Clipboard history is invalid. Clear it with Super + Ctrl + Shift + V.\n' >&2
    exit 1
  fi
  jq -c --arg dir "$state_root" '{version: 1, dir: $dir, items: (.items // [])}' "$file"
}

remove_item() {
  local id=$1 temporary
  [[ $id =~ ^[0-9a-f]{64}$ ]] || { printf 'Invalid item id.\n' >&2; exit 2; }
  lock_state
  temporary=$(mktemp "$state_root/.history.XXXXXX")
  jq --arg id "$id" '{version: 1, items: [.items[] | select(.id != $id)]}' "$file" > "$temporary"
  mv -f -- "$temporary" "$file"
  gc_images
  exec 8>&-
}

clear_history() {
  local path
  lock_state
  write_state <<'JSON'
{"version":1,"items":[]}
JSON
  for path in "$images"/*; do
    [[ -e $path ]] || continue
    rm -f -- "$path"
  done
  exec 8>&-
}

trim_history() {
  local temporary
  read_limits
  lock_state
  temporary=$(mktemp "$state_root/.history.XXXXXX")
  jq --argjson limit "$history_size" '{version: 1, items: (.items // [])[:$limit]}' "$file" > "$temporary"
  mv -f -- "$temporary" "$file"
  gc_images
  exec 8>&-
}

copy_item() {
  local id=$1 kind mime relative path temporary
  [[ $id =~ ^[0-9a-f]{64}$ ]] || { printf 'Invalid item id.\n' >&2; exit 2; }
  ensure_state
  {
    IFS= read -r kind || true
    IFS= read -r mime || true
    IFS= read -r relative || true
  } < <(jq -r --arg id "$id" '
    .items[] | select(.id == $id) |
    [(.kind // ""), (.mime // ""), (.file // "")] | .[]
  ' "$file")
  [[ -n $kind ]] || { printf 'Clipboard item not found.\n' >&2; exit 1; }
  [[ -n $mime ]] || mime='text/plain;charset=utf-8'
  if [[ $kind == image ]]; then
    path=$state_root/$relative
    [[ -f $path ]] || { printf 'Clipboard image is missing.\n' >&2; exit 1; }
    # wl-copy forks a long-lived owner. Keep the child away from Quickshell's
    # stderr pipe so the copy Process can finish immediately.
    if ! wl-copy --type "$mime" < "$path" 2>/dev/null; then
      printf 'Could not copy the clipboard image.\n' >&2
      exit 1
    fi
    return 0
  fi
  temporary=$(mktemp "$state_root/.copy.XXXXXX")
  jq -rj --arg id "$id" '.items[] | select(.id == $id) | .text' "$file" > "$temporary"
  if ! wl-copy --type "$mime" < "$temporary" 2>/dev/null; then
    rm -f -- "$temporary"
    printf 'Could not copy the clipboard text.\n' >&2
    exit 1
  fi
  rm -f -- "$temporary"
}

case ${1:-} in
  read) read_history ;;
  watch)
    # Seed the history with the current clipboard, then follow changes.
    bash "${BASH_SOURCE[0]}" capture || true
    exec wl-paste --watch bash "${BASH_SOURCE[0]}" capture
    ;;
  capture) capture ;;
  copy) [[ $# == 2 ]] || usage; copy_item "$2" ;;
  remove) [[ $# == 2 ]] || usage; remove_item "$2" ;;
  clear) clear_history ;;
  trim) trim_history ;;
  path) printf '%s\n' "$state_root" ;;
  *) usage ;;
esac
