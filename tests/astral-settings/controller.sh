#!/usr/bin/env bash
set -euo pipefail
entry=$XDG_CONFIG_HOME/quickshell/settings.qml
dispatch=$XDG_CONFIG_HOME/quickshell/dispatch.sh
cleanup() { qs kill -p "$entry" >/dev/null 2>&1 || true; }
trap cleanup EXIT
bash "$dispatch" "$entry" settings daemon > "$ASTRAL_SETTINGS_FIXTURE/daemon.log" 2>&1 &
first=$!
bash "$dispatch" "$entry" settings open > "$ASTRAL_SETTINGS_FIXTURE/open.log" 2>&1 &
second=$!
wait "$first"
wait "$second"
[[ $(qs list --json -p "$entry" | jq length) == 1 ]]
bash "$dispatch" "$entry" settings open
[[ $(qs list --json -p "$entry" | jq length) == 1 ]]
[[ $(qs ipc -p "$entry" call settings state) == ready ]]
bash "$dispatch" "$entry" settings close
printf 'ASTRAL_SETTINGS_CONTROLLER_PASS\n'
