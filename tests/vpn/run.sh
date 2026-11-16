#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch vpn)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin" "$runtime/home"; export PATH="$runtime/bin:$PATH"
sed 's|../../config/quickshell/|./|g' tests/vpn/service.qml > "$runtime/config/vpn-test.qml"
: > "$runtime/commands"
output=$(VPN_FIXTURE_LOG="$runtime/commands" XDG_RUNTIME_DIR="$runtime" HOME="$runtime/home" PATH="$PWD/tests/vpn:$PATH" QT_QPA_PLATFORM=offscreen WAYLAND_DISPLAY= timeout 40 qs --path "$runtime/config/vpn-test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *VPN_SERVICE_PASS* && $output != *VPN_SERVICE_FAIL* ]]

# Only explicit user actions may reach nmcli, and each runs exactly once.
[[ $(rg -c -F 'connection up uuid wg-id' "$runtime/commands") == 1 ]]
[[ $(rg -c -F 'connection up ' "$runtime/commands") == 1 ]]
[[ $(rg -c -F 'connection down uuid wg-id' "$runtime/commands") == 1 ]]
[[ $(rg -c -F 'connection import type wireguard file /tmp/fixture.conf' "$runtime/commands") == 1 ]]
[[ $(rg -c -F 'connection import type openvpn file /tmp/office.ovpn' "$runtime/commands") == 1 ]]
[[ $(rg -c -F 'connection delete uuid vpn-id' "$runtime/commands") == 1 ]]
[[ $(rg -c -F 'connection import type wireguard file /tmp/fail.conf' "$runtime/commands") == 1 ]]
