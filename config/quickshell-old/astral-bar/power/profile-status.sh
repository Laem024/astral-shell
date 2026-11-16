#!/usr/bin/env bash
set -euo pipefail
# Quickshell 0.3.2's native setter is optimistic. Independently read the daemon
# before exposing a requested change as applied. No profile writes here.
service=org.freedesktop.UPower.PowerProfiles
result=$(busctl --system --timeout=2 get-property "$service" /org/freedesktop/UPower/PowerProfiles "$service" ActiveProfile)
case $result in
  's "power-saver"') printf 'power-saver\n' ;;
  's "balanced"') printf 'balanced\n' ;;
  's "performance"') printf 'performance\n' ;;
  *) printf 'Invalid power profile response.\n' >&2; exit 1 ;;
esac
