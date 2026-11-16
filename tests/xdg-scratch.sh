#!/usr/bin/env bash
# Freeze the root before nested suites replace HOME or their XDG environment.
trap 'exit 130' INT
trap 'exit 143' TERM
export ASTRAL_TEST_SCRATCH_ROOT=${ASTRAL_TEST_SCRATCH_ROOT:-${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/astral-shell/tests}
astral_test_scratch() {
  local base=$ASTRAL_TEST_SCRATCH_ROOT directory label=${1:-check}
  [[ $base == /* ]] || { printf 'Astral test scratch root must be absolute.\n' >&2; return 1; }
  # Budget for /run/quickshell/<instance>/ipc.sock and D-Bus socket names.
  if (( ${#base} + ${#label} + 49 > 107 )); then
    printf 'Astral test path is too long for IPC sockets: %s (use a shorter XDG runtime/cache root).\n' "$base" >&2
    return 1
  fi
  [[ ! -L $base ]] || return 1
  (umask 077; mkdir -p -- "$base") || return 1
  [[ -d $base && -O $base && $(stat -c %a -- "$base") == 700 ]] || {
    printf 'Astral test scratch root must be owned by this user with mode 700: %s\n' "$base" >&2; return 1;
  }
  directory=$(mktemp -d "$base/${label}-XXXXXXXX") || return 1
  printf '%s\n' "$directory"
}

# Private bus configuration and sockets, cleaned by the process that created them.
astral_test_dbus() (
  local bus_directory
  bus_directory=$(astral_test_scratch bus) || exit 1
  trap 'rm -rf -- "$bus_directory"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  cat > "$bus_directory/session.conf" <<BUS
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path=$bus_directory/bus</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
BUS
  dbus-run-session --config-file="$bus_directory/session.conf" "$@"
)
