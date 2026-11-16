#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
for command in pactl pw-cat qs; do
  command -v "$command" >/dev/null || { printf 'Missing existing test tool: %s\n' "$command" >&2; exit 1; }
done
runtime=$(astral_test_scratch audio)
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
sed 's|../../config/quickshell/|./|g' tests/audio/controls.qml > "$runtime/config/test.qml"
module=$(pactl load-module module-null-sink sink_name=astral_audio_test)
input_module=
stream_pid=
cleanup() {
  if [[ -n $stream_pid ]]; then kill "$stream_pid" 2>/dev/null || true; wait "$stream_pid" 2>/dev/null || true; fi
  if [[ -n $input_module ]]; then pactl unload-module "$input_module"; fi
  pactl unload-module "$module"
  rm -rf -- "$runtime"
}
trap cleanup EXIT
input_module=$(pactl load-module module-remap-source master=astral_audio_test.monitor source_name=astral_audio_input_test)
pw-cat --playback --raw --rate 48000 --channels 2 --format s16 --target astral_audio_test --properties '{ application.name = "astral-audio-test" }' /dev/zero &
stream_pid=$!
output=$(QT_QPA_PLATFORM=offscreen timeout 12 qs --path "$runtime/config/test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *AUDIO_CONTROLS_PASS* && $output != *AUDIO_FAIL* ]]
