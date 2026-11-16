#!/usr/bin/env bash
set -euo pipefail
umask 077
state_root=${XDG_STATE_HOME:-${HOME:?}/.local/state}
cache_root=${XDG_CACHE_HOME:-${HOME:?}/.cache}
[[ $state_root == /* ]] || state_root=$HOME/.local/state
[[ $cache_root == /* ]] || cache_root=$HOME/.cache
state_dir=$state_root/astral-shell/astral-wallpaper
cache_dir=$cache_root/astral-shell/astral-wallpaper
fail() { printf '%s\n' "$*" >&2; exit 1; }
# All requests, including the optional key, arrive on stdin, never argv.
case ${1:-} in
  read)
    if [[ -f $state_dir/state.json ]]; then cat -- "$state_dir/state.json"; else printf '{}\n'; fi
    ;;
  write)
    mkdir -p -- "$state_dir"
    temporary=$(mktemp "$state_dir/.state.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    jq -e 'select(.version == 1)' > "$temporary"
    mv -f -- "$temporary" "$state_dir/state.json"
    ;;
  scan)
    request=$(cat)
    folder=$(jq -er '.folder | select(startswith("/"))' <<< "$request")
    [[ -d $folder && -r $folder && -x $folder ]] || fail 'The wallpaper folder is unavailable.'
    # NUL delimiters preserve spaces, tabs, newlines and shell metacharacters.
    temporary=$(mktemp)
    trap 'rm -f -- "$temporary"' EXIT
    find "$folder" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \) -printf '%P\0' > "$temporary"
    jq -Rs --arg folder "${folder%/}/" 'split("\u0000") | map(select(length > 0) | . as $relative | {path: ($folder + .), relative: ., name: (split("/") | last)}) | sort_by(.relative)' "$temporary"
    ;;
  thumbnail)
    request=$(cat)
    path=$(jq -er '.path | select(startswith("/"))' <<< "$request")
    [[ -f $path ]] || fail 'The wallpaper file is missing.'
    mkdir -p -- "$cache_dir"
    key=$( { printf '%s\0' "$path"; stat -c '%s:%y' -- "$path"; } | sha256sum)
    target=$cache_dir/${key%% *}.jpg
    exec 9>"$target.lock"
    flock -w 20 9
    if [[ ! -s $target ]]; then
      # Limit expensive decoders while keeping thumbnail requests asynchronous.
      exec 8>"$cache_dir/thumbnail-worker.lock"
      flock -w 60 8
      temporary=$(mktemp "$cache_dir/.thumb.XXXXXX")
      trap 'rm -f -- "$temporary"' EXIT
      timeout 20 ffmpeg -v error -nostdin -i "$path" -frames:v 1 -vf 'scale=384:216:force_original_aspect_ratio=increase,crop=384:216' -f image2 -c:v mjpeg -threads 1 -y "$temporary" 2>/dev/null || fail 'Could not create the thumbnail.'
      mv -f -- "$temporary" "$target"
    fi
    jq -n --arg path "$target" '{path:$path}'
    ;;
  key-status)
    if [[ -s $state_dir/api-key ]]; then printf 'saved\n'; else printf 'empty\n'; fi
    ;;
  key)
    mkdir -p -- "$state_dir"
    chmod 700 "$state_dir"
    temporary=$(mktemp "$state_dir/.key.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    request=$(cat)
    key=$(jq -er '.key | select(type == "string")' <<< "$request")
    [[ -z $key || $key =~ ^[a-zA-Z0-9]+$ ]] || fail 'Invalid API key.'
    if [[ -z $key ]]; then rm -f -- "$state_dir/api-key"; else printf '%s' "$key" > "$temporary"; mv -f -- "$temporary" "$state_dir/api-key"; fi
    ;;
  search|download)
    operation=$1
    request=$(cat)
    mkdir -p -- "$cache_dir" "$state_dir"
    chmod 700 "$state_dir"
    work=$(mktemp -d "$cache_dir/.request.XXXXXX")
    trap 'rm -rf -- "$work"; if [[ -n ${temporary:-} ]]; then rm -f -- "$temporary"; fi' EXIT
    if [[ $operation == search ]]; then
      query=$(jq -r '.query | @uri' <<< "$request")
      page=$(jq -er '.page | select(type == "number" and . >= 1 and . <= 1000) | floor' <<< "$request")
      url="https://wallhaven.cc/api/v1/search?purity=100&categories=111&sorting=relevance&q=$query&page=$page"
      if [[ -s $state_dir/api-key ]]; then
        key=$(cat -- "$state_dir/api-key")
        [[ $key =~ ^[a-zA-Z0-9]+$ ]] || fail 'The saved API key is invalid.'
        url+="&apikey=$key"
      fi
    else
      url=$(jq -er '.url | select(test("^https://w\\.wallhaven\\.cc/full/[a-z0-9]{2}/wallhaven-[a-z0-9]+\\.(jpg|png|webp)$"))' <<< "$request") || fail 'Invalid Wallhaven download URL.'
    fi
    # A private curl configuration keeps the authenticated URL out of ps and logs.
    printf 'url = "%s"\n' "$url" > "$work/curl.conf"
    code=$(curl --config "$work/curl.conf" --silent --proto '=https' --connect-timeout 15 --max-time 180 --output "$work/body" --write-out '%{http_code}' 2>/dev/null) || fail 'Network error. Check your connection and try again.'
    case $code in
      200) ;;
      401|403) fail 'Wallhaven authentication failed. Check the API key.' ;;
      429) fail 'Wallhaven rate limit reached. Try again later.' ;;
      *) fail "Wallhaven request failed (HTTP $code)." ;;
    esac
    if [[ $operation == search ]]; then
      jq -e '{data: [.data[] | select(.purity == "sfw") | {id, path, resolution, thumbs}], meta: {current_page: .meta.current_page, last_page: .meta.last_page}}' "$work/body" || fail 'Invalid Wallhaven response.'
    else
      folder=$(jq -er '.folder | select(startswith("/"))' <<< "$request")
      collection=$(jq -er '.collection | select(. == "shared" or . == "light" or . == "dark")' <<< "$request")
      [[ $collection == shared ]] || folder=$folder/$collection
      mkdir -p -- "$folder"
      # Validate a complete decodable image before exposing it to library scans.
      ffmpeg -v error -nostdin -i "$work/body" -frames:v 1 -f null - 2>/dev/null || fail 'The downloaded image is damaged.'
      temporary=$(mktemp "$folder/.wallhaven.XXXXXX")
      cp -- "$work/body" "$temporary"
      target=$folder/${url##*/}
      mv -f -- "$temporary" "$target"
      jq -n --arg path "$target" '{path:$path}'
    fi
    ;;
  *) fail 'Unknown wallpaper operation.' ;;
esac
