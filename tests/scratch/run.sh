#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
scratch=$(astral_test_scratch scratch)
trap 'rm -rf -- "$scratch"' EXIT
# Parallel callers get different private directories; cleanup preserves peers.
astral_test_scratch a > "$scratch/a" &
a=$!
astral_test_scratch a > "$scratch/b" &
b=$!
wait "$a" "$b"
one=$(cat "$scratch/a"); two=$(cat "$scratch/b")
[[ $one != "$two" && $(stat -c %a "$one") == 700 ]]
rm -r -- "$one"
[[ -d $two ]]
rm -r -- "$two"
# Cache fallback is selected before replacing HOME, and remains stable.
result=$(env -u XDG_RUNTIME_DIR -u ASTRAL_TEST_SCRATCH_ROOT XDG_CACHE_HOME="${ASTRAL_TEST_SCRATCH_ROOT%/astral-shell/tests}" bash -c '
  source tests/xdg-scratch.sh
  HOME=/nonexistent XDG_CACHE_HOME=/nonexistent
  astral_test_scratch f
')
[[ $result == "$ASTRAL_TEST_SCRATCH_ROOT/"* ]]
rm -r -- "$result"
# A long path fails before creating any directories or launching a process.
if ASTRAL_TEST_SCRATCH_ROOT="$scratch/$(printf '%090d' 0)" astral_test_scratch long > "$scratch/out" 2> "$scratch/error"; then exit 1; fi
rg -q 'too long for IPC' "$scratch/error"
# The bus and all of its private resources disappear on success and failure.
ASTRAL_TEST_SCRATCH_ROOT=$scratch astral_test_dbus -- true
if ASTRAL_TEST_SCRATCH_ROOT=$scratch astral_test_dbus -- false; then exit 1; fi
[[ -z $(find "$scratch" -maxdepth 1 -name 'bus-*' -print) ]]
# Interruption runs EXIT cleanup for exactly the interrupted invocation.
cat > "$scratch/interrupt.sh" <<'CHILD'
  set -euo pipefail
  source tests/xdg-scratch.sh
  interrupted=$(astral_test_scratch sig)
  trap 'rm -rf -- "$interrupted"' EXIT
  printf "%s\n" "$interrupted" > "$1"
  while :; do sleep 0.05; done
CHILD
bash "$scratch/interrupt.sh" "$scratch/interrupted" &
interrupted_pid=$!
for ((attempt=0; attempt<100; attempt++)); do
  [[ ! -s $scratch/interrupted ]] || break
  sleep 0.01
done
[[ -s $scratch/interrupted ]]
kill -TERM "$interrupted_pid"
wait "$interrupted_pid" || [[ $? == 143 ]]
[[ ! -e $(cat "$scratch/interrupted") ]]
printf 'SCRATCH_PASS\n'
