#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

source tests/xdg-scratch.sh
runtime=$(astral_test_scratch configs)
trap 'rm -rf -- "$runtime"' EXIT
export HOME=$runtime/home
export XDG_CONFIG_HOME=$HOME/.config
export XDG_RUNTIME_DIR=$runtime/run
mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

fail() { printf 'CONFIGS_FAIL: %s\n' "$*" >&2; exit 1; }

# Both Qt configuration modules are installed on first apply.
bash scripts/manage-configs.sh apply qt5ct > "$runtime/qt5ct-apply.log"
bash scripts/manage-configs.sh apply qt6ct > "$runtime/qt6ct-apply.log"
for name in qt5ct qt6ct; do
  file=$XDG_CONFIG_HOME/$name/$name.conf
  [[ -f $file ]] || fail "$name.conf was not installed"
  grep -qx '\[Appearance\]' "$file" || fail "$name.conf has no Appearance section"
  grep -qx 'icon_theme=Papirus-Dark' "$file" || fail "$name.conf does not select Papirus-Dark"
done

# Reapplying identical content neither rewrites nor creates a backup.
bash scripts/manage-configs.sh apply qt6ct > "$runtime/qt6ct-reapply.log"
grep -q 'already matches' "$runtime/qt6ct-reapply.log" || fail 'identical apply was not skipped'
[[ ! -e $XDG_CONFIG_HOME/qt6ct/.backups ]] || fail 'identical apply created a backup'

# A user edit is backed up before the managed value replaces it.
printf '[Appearance]\nicon_theme=Adwaita\n' > "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
bash scripts/manage-configs.sh apply qt6ct > "$runtime/qt6ct-replace.log"
backup=$(find "$XDG_CONFIG_HOME/qt6ct/.backups" -mindepth 1 -maxdepth 1 -type d | head -n 1)
[[ -n $backup ]] || fail 'replacing a user edit did not create a backup'
grep -qx 'icon_theme=Adwaita' "$backup/qt6ct.conf" || fail 'backup does not preserve the user edit'
grep -qx 'icon_theme=Papirus-Dark' "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" || fail 'managed value was not restored'

# The shared Hyprtoolkit theme is installed with the Hyprland configuration.
bash scripts/manage-configs.sh apply hyprland > "$runtime/hyprland-apply.log"
toolkit_config=$XDG_CONFIG_HOME/hypr/hyprtoolkit.conf
[[ -f $toolkit_config ]] || fail 'hyprtoolkit.conf was not installed'
grep -qx 'accent             = 0xFF8FD3C0' "$toolkit_config" \
  || fail 'hyprtoolkit.conf does not use the Astral accent'
grep -qx 'icon_theme            = Papirus-Dark' "$toolkit_config" \
  || fail 'hyprtoolkit.conf does not select Papirus-Dark'

# A partial bar installation includes shared dependencies and public commands.
bash scripts/manage-configs.sh apply quickshell --module astral-bar > "$runtime/polkit-apply.log"
for file in shell.qml settings.json; do
  [[ -f $XDG_CONFIG_HOME/quickshell/astral-bar/$file ]] \
    || fail "astral-bar/$file was not installed"
done
[[ -x $HOME/.local/bin/astral-bar ]] || fail 'the astral-bar command was not installed'

# apply all includes the bar, so install.sh and install.sh update cover them.
rm -rf -- "$XDG_CONFIG_HOME/qt5ct" "$XDG_CONFIG_HOME/qt6ct" \
  "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/quickshell"
bash scripts/manage-configs.sh apply all --dry-run > "$runtime/all.log"
grep -qF "Create: $XDG_CONFIG_HOME/qt5ct/qt5ct.conf" "$runtime/all.log" || fail 'apply all does not include qt5ct'
grep -qF "Create: $XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "$runtime/all.log" || fail 'apply all does not include qt6ct'
grep -qF "Create: $XDG_CONFIG_HOME/hypr/hyprtoolkit.conf" "$runtime/all.log" \
  || fail 'apply all does not include hyprtoolkit.conf'
grep -qF "Create: $XDG_CONFIG_HOME/quickshell/astral-bar/shell.qml" "$runtime/all.log" \
  || fail 'apply all does not include the bar'

# --no-backup overwrites project-managed files, keeps destination-only files and
# never creates a backup. fish_variables is the real-world example of this rule.
bash scripts/manage-configs.sh apply qt6ct > "$runtime/qt6ct-seed.log"
printf 'user-owned=keep\n' > "$XDG_CONFIG_HOME/qt6ct/fish_variables"
printf '[Appearance]\nicon_theme=Adwaita\n' > "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
bash scripts/manage-configs.sh apply qt6ct --no-backup > "$runtime/qt6ct-no-backup.log"
grep -qx 'icon_theme=Papirus-Dark' "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" \
  || fail '--no-backup did not overwrite the project-managed file'
grep -qx 'user-owned=keep' "$XDG_CONFIG_HOME/qt6ct/fish_variables" \
  || fail '--no-backup removed a destination-only file'
[[ ! -e $XDG_CONFIG_HOME/qt6ct/.backups ]] || fail '--no-backup created a backup directory'
grep -q 'Overwrite without backup' "$runtime/qt6ct-no-backup.log" \
  || fail '--no-backup did not print the overwrite plan'
bash scripts/manage-configs.sh apply all --dry-run --no-backup > "$runtime/all-no-backup.log" \
  || fail 'apply all does not accept --no-backup'

printf 'CONFIGS_PASS\n'

# Retire only exact project copies, backing them up before deletion.
mkdir -p "$XDG_CONFIG_HOME/hypr"
cat > "$runtime/start-idle.sh" <<'LEGACY'
#!/usr/bin/env bash
set -euo pipefail
: "${XDG_RUNTIME_DIR:?A user runtime directory is required}"
# Hold the mutex in Hypridle itself. Reloads/manual starts through this helper
# cannot create another instance. An existing external Hypridle is respected.
exec 9>"$XDG_RUNTIME_DIR/astral-hypridle.lock"
flock -n 9 || exit 0
pgrep -u "$UID" -x hypridle >/dev/null && exit 0
exec hypridle -c "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
LEGACY
cat > "$runtime/hypridle.conf" <<'LEGACY'
# Optional display-only fallback. Do not start alongside Astral's native idle
# worker (the astral-idle registry entry), which also owns display power saving.
general {
  after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
  timeout = 600
  on-timeout = hyprctl dispatch dpms off
  on-resume = hyprctl dispatch dpms on
}
LEGACY
for file in start-idle.sh hypridle.conf; do cp "$runtime/$file" "$XDG_CONFIG_HOME/hypr/$file"; done
bash scripts/manage-configs.sh apply hyprland --dry-run > "$runtime/retired-dry"
[[ -f $XDG_CONFIG_HOME/hypr/start-idle.sh && ! -d $XDG_CONFIG_HOME/hypr/.backups ]]
bash scripts/manage-configs.sh apply hyprland > "$runtime/retired-apply"
for file in start-idle.sh hypridle.conf; do
  [[ ! -e $XDG_CONFIG_HOME/hypr/$file ]]
  backup=$(find "$XDG_CONFIG_HOME/hypr/.backups" -name "$file" -print -quit)
  cmp "$runtime/$file" "$backup"
done
cp "$runtime/start-idle.sh" "$XDG_CONFIG_HOME/hypr/start-idle.sh"
printf '# custom\n' > "$XDG_CONFIG_HOME/hypr/hypridle.conf"
backups=$(find "$XDG_CONFIG_HOME/hypr/.backups" -type f | wc -l)
bash scripts/manage-configs.sh apply hyprland --no-backup > "$runtime/retired-custom"
[[ ! -e $XDG_CONFIG_HOME/hypr/start-idle.sh && $(cat "$XDG_CONFIG_HOME/hypr/hypridle.conf") == '# custom' ]]
[[ $(find "$XDG_CONFIG_HOME/hypr/.backups" -type f | wc -l) == "$backups" ]]
rg -q 'Preserve customized retired file' "$runtime/retired-custom"
printf 'CONFIGS_RETIRED_PASS\n'
