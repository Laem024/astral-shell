#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then
  astral_test_dbus -- bash "$0" --isolated; exit $?
fi
runtime=$(astral_test_scratch weather)
trap 'result=$?; if (( result != 0 )); then for log in "$runtime"/*.log; do [[ -f $log ]] && cat "$log"; done; fi; rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin" "$runtime/home" "$runtime/run" "$runtime/state" "$runtime/cache" "$runtime/data"
chmod 700 "$runtime/run"
export PATH="$runtime/bin:$PATH"
export HOME="$runtime/home" XDG_CONFIG_HOME="$runtime/config" XDG_STATE_HOME="$runtime/state" XDG_CACHE_HOME="$runtime/cache" XDG_DATA_HOME="$runtime/data" XDG_RUNTIME_DIR="$runtime/run"
export QT_QPA_PLATFORM=offscreen ASTRAL_TEST_DIR="$runtime"

cat > "$runtime/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ -f $ASTRAL_TEST_DIR/offline ]]; then
  printf 'offline\n' >&2
  exit 6
fi
case "$*" in
  *ipwho.is*) cat "$ASTRAL_TEST_DIR/geo.json" ;;
  *api.open-meteo.com*) cat "$ASTRAL_TEST_DIR/weather.json" ;;
  *) printf 'unexpected curl request: %s\n' "$*" >&2; exit 2 ;;
esac
MOCK
cat > "$runtime/bin/timedatectl" <<'MOCK'
#!/usr/bin/env bash
printf 'America/Santo_Domingo\n'
MOCK
cat > "$runtime/bin/nmcli" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$runtime/bin/curl" "$runtime/bin/timedatectl" "$runtime/bin/nmcli"

cat > "$runtime/geo.json" <<'JSON'
{"success":true,"city":"Santiago de los Caballeros","region":"Provincia de Santiago","country":"Dominican Republic","country_code":"DO","latitude":19.4503599,"longitude":-70.6908479,"timezone":{"id":"America/Santo_Domingo","abbr":"AST","is_dst":false,"offset":-14400,"utc":"-04:00"}}
JSON
cat > "$runtime/weather.json" <<'JSON'
{"latitude":19.4504,"longitude":-70.6908,"utc_offset_seconds":-14400,"timezone":"America/Santo_Domingo","timezone_abbreviation":"GMT-4","current_units":{"temperature_2m":"°C","wind_speed_10m":"km/h"},"current":{"temperature_2m":28.6,"apparent_temperature":32.8,"relative_humidity_2m":76,"wind_speed_10m":13.2,"weather_code":95},"daily":{"time":["2026-11-12","2026-11-13","2026-11-14","2026-11-15","2026-11-16","2026-11-17","2026-11-18"],"weather_code":[95,95,95,95,51,95,1],"temperature_2m_min":[23.0,25.2,24.9,23.2,22.6,22.2,22.2],"temperature_2m_max":[29.9,29.7,29.5,28.8,30.8,30.3,30.0]}}
JSON

sed 's|../../config/quickshell/|./|g' tests/weather/check.qml > "$runtime/config/check.qml"
cache=$XDG_CACHE_HOME/astral-shell/astral-bar/weather.json

run_case() {
  local mode=$1
  export ASTRAL_WEATHER_TEST_MODE=$mode
  timeout 25 qs --path "$runtime/config/check.qml" --no-color > "$runtime/$mode.log" 2>&1 \
    || { cat "$runtime/$mode.log"; exit 1; }
  printf '%s\n' "$(cat "$runtime/$mode.log")"
  [[ $(cat "$runtime/$mode.log") == *"WEATHER_PASS $mode"* ]] || exit 1
  if rg -q 'WEATHER_FAIL|TypeError|ReferenceError|Binding loop|Failed to load configuration' "$runtime/$mode.log"; then
    exit 1
  fi
}

run_case online
for ((attempt = 0; attempt < 80; attempt++)); do
  [[ -s $cache ]] && break
  sleep 0.05
done
[[ -s $cache ]] || { printf 'Missing weather cache\n' >&2; exit 1; }
jq -e '.version == 1 and .location.city == "Santiago de los Caballeros" and .weather.current.temperature_2m == 28.6 and .weatherSaved > 0' "$cache" >/dev/null

touch "$runtime/offline"
run_case cached
rm -- "$cache"
run_case system

printf 'WEATHER_PASS\n'
