#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch audio)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
sed 's|../../config/quickshell/|./|g' tests/audio/service.qml > "$runtime/config/audio-test.qml"
output=$(QT_QPA_PLATFORM=offscreen timeout 10 qs --path "$runtime/config/audio-test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *AUDIO_SMOKE_PASS* ]]
! [[ $output == *'ERROR'* || $output == *'TypeError'* || $output == *'ReferenceError'* ]]
