#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh

fail() { printf 'SDDM test failed: %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f $1 ]] || fail "missing file: $1"; }
assert_dir() { [[ -d $1 ]] || fail "missing directory: $1"; }

for tool in mktemp find grep stat; do
  command -v "$tool" >/dev/null 2>&1 || fail "required command not found: $tool"
done

bash -n install.sh scripts/install-sddm.sh scripts/sddm-background.sh || fail 'shell syntax'

temporary=$(astral_test_scratch sddm)
trap 'rm -rf -- "$temporary"' EXIT
runner=/usr/lib/qt6/bin/qmltestrunner
if [[ -x $runner ]]; then
  XDG_CACHE_HOME="$temporary/cache" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
    "$runner" -input tests/sddm
fi
stage=$temporary/stage
theme=$stage/usr/share/sddm/themes/astral
config=$stage/etc/sddm.conf.d/zz-astral-theme.conf
helper=$stage/usr/local/bin/astral-sddm-background

echo '== install =='
bash scripts/install-sddm.sh --stage "$stage" install >/dev/null
assert_dir "$theme"
assert_file "$theme/Main.qml"
assert_file "$theme/metadata.desktop"
assert_file "$theme/theme.conf"
assert_file "$theme/.astral-theme"
assert_file "$theme/faces/.face.icon"
assert_file "$theme/assets/backgrounds/aurora.jpg"
assert_file "$config"
assert_file "$helper"
grep -qx 'Current=astral' "$config" || fail 'Current=astral missing'
grep -qx 'EnableAvatars=true' "$config" || fail 'EnableAvatars=true missing'
grep -qx 'Theme-Id=astral' "$theme/metadata.desktop" || fail 'Theme-Id missing'
[[ $(stat -c %a "$theme/Main.qml") == 644 ]] || fail 'theme file mode'
[[ $(stat -c %a "$helper") == 755 ]] || fail 'helper mode'
[[ -z $(find "$stage" -name .backups -print -quit) ]] || fail 'backup directory created'
[[ -z $(find "$stage" -name '*.backup*' -print -quit) ]] || fail 'backup file created'
if grep -RIl -- "$PWD/config/sddm" "$theme" >/dev/null 2>&1; then
  fail 'installed theme contains a repository path'
fi
[[ $(find "$stage/usr/share/sddm/themes" -mindepth 1 -maxdepth 1 -type d | wc -l) == 1 ]] \
  || fail 'installer touched another theme directory'

echo '== update preserves theme.conf =='
printf '\n; test customization\n' >> "$theme/theme.conf"
bash scripts/install-sddm.sh --stage "$stage" update >/dev/null
grep -q 'test customization' "$theme/theme.conf" || fail 'theme.conf was overwritten'

echo '== update installs a missing theme =='
rm -rf "$theme"
bash scripts/install-sddm.sh --stage "$stage" update >/dev/null
assert_file "$theme/Main.qml"

echo '== foreign theme is refused =='
rm -rf "$theme"
mkdir -p "$theme"
printf '[SddmGreeterTheme]\nTheme-Id=other\n' > "$theme/metadata.desktop"
if bash scripts/install-sddm.sh --stage "$stage" install >/dev/null 2>&1; then
  fail 'a foreign theme was replaced'
fi

echo '== background helper =='
rm -rf "$theme"
bash scripts/install-sddm.sh --stage "$stage" install >/dev/null
ASTRAL_SDDM_THEME_DIR="$theme" bash scripts/sddm-background.sh nebula >/dev/null
grep -qx 'background=nebula' "$theme/theme.conf" || fail 'preset was not applied'
ASTRAL_SDDM_THEME_DIR="$theme" bash scripts/sddm-background.sh \
  config/sddm/astral/assets/backgrounds/dusk.jpg >/dev/null
assert_file "$theme/assets/backgrounds/custom.jpg"
grep -qx 'background=assets/backgrounds/custom.jpg' "$theme/theme.conf" \
  || fail 'custom image was not applied'
ASTRAL_SDDM_THEME_DIR="$theme" bash scripts/sddm-background.sh --list \
  | grep -q '^Current: assets/backgrounds/custom.jpg$' || fail 'helper --list output'

echo '== idempotence =='
output=$(bash scripts/install-sddm.sh --stage "$stage" update)
printf '%s\n' "$output" | grep -q 'Updated 0 file(s)' || fail 'update was not idempotent'
grep -q 'assets/backgrounds/custom.jpg' "$theme/theme.conf" \
  || fail 'theme.conf changed during update'

echo 'SDDM installer tests: PASS'
