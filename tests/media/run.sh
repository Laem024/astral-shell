#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch media)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
mkdir "$runtime/run"
sed 's|../../config/quickshell/|./|g' tests/media/service.qml > "$runtime/config/media-test.qml"
output=$(XDG_RUNTIME_DIR="$runtime/run" QT_QPA_PLATFORM=offscreen timeout 8 qs --path "$runtime/config/media-test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *MEDIA_PASS* && $output != *MEDIA_FAIL* ]]
! [[ $output == *'ERROR'* || $output == *'TypeError'* || $output == *'ReferenceError'* || $output == *'Binding loop'* ]]
