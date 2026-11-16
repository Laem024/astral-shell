#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/network
runtime=$(astral_test_scratch network)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
sed 's|../../config/quickshell/|./|g' tests/network/service.qml > "$runtime/config/network-test.qml"
output=$(NETWORK_FIXTURE_LOG="$runtime/commands" XDG_RUNTIME_DIR="$runtime" PATH="$PWD/tests/network:$PATH" QT_QPA_PLATFORM=offscreen WAYLAND_DISPLAY= timeout 60 qs --path "$runtime/config/network-test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *NETWORK_SERVICE_PASS* && $output != *NETWORK_SERVICE_FAIL* && $output != *test-secret* ]]

# Writes from the second view are ignored during activation. Only the newly
# created UUID may be rolled back; the preexisting profile is deleted once later.
[[ $(rg -c 'connection delete uuid saved-id ' "$runtime/commands") == 1 ]]
[[ $(rg -c 'connection delete uuid [0-9a-f-]{36} ' "$runtime/commands") == 1 ]]
! rg -q 'test-secret' "$runtime/commands"
[[ $(rg -c " monitor " "$runtime/commands") -ge 2 ]]
