#!/usr/bin/env bash
# Exit 0 only when every MPRIS service can be queried and none is playing.
# busctl is already supplied by systemd; no playerctl or Python dependency.
set -euo pipefail
bash "$(dirname -- "${BASH_SOURCE[0]}")/power/caffeine.sh" allowed || exit 1
names=$(busctl --user --timeout=2 --no-pager --no-legend list) || exit 2
while read -r name _; do
  [[ $name == org.mpris.MediaPlayer2.* ]] || continue
  status=$(busctl --user --timeout=2 get-property "$name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus) || exit 2
  case $status in
    's "Playing"') exit 1 ;;
    's "Paused"'|'s "Stopped"') ;;
    *) exit 2 ;;
  esac
done <<< "$names"
