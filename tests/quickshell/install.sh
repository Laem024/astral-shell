#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
scratch=$(astral_test_scratch install-test)
trap 'rm -rf -- "$scratch"' EXIT
export HOME=$scratch/home XDG_CONFIG_HOME=$scratch/config
mkdir -p -- "$HOME" "$XDG_CONFIG_HOME"
install_config() { bash scripts/manage-configs.sh apply quickshell "$@" > "$scratch/log"; }
install_config --dry-run
[[ ! -e $XDG_CONFIG_HOME/quickshell && ! -e $HOME/.local/bin ]]
install_config
root=$XDG_CONFIG_HOME/quickshell
[[ -f $root/settings.json && -f $root/common/Theme.qml && -f $root/astral-bar/shell.qml ]]
[[ -f $root/bar.qml && -f $root/recorder.qml && -f $root/astral-bar/BarRoot.qml ]]
jq -e '.modules[] | select(.id == "astral-bar") | .path == "bar.qml"' "$root/settings.json" >/dev/null
[[ -x $HOME/.local/bin/astral-shell && -x $HOME/.local/bin/astral-bar ]]
[[ $(find "$HOME/.local/bin" -type f | wc -l) == 10 ]]
[[ -f $root/lock.qml && -f $root/session.qml && ! -e $root/astral-bar/session.sh ]]
[[ $($HOME/.local/bin/astral-bar workspace-count) == 10 ]]
[[ $($HOME/.local/bin/astral-shell workspace-count) == 10 ]]
install_config
[[ ! -e $root/.backups ]]
# Migrate old common preferences from the module, preserving local preferences.
jq '.scale=1.5 | .colors={dark:{cyan:"#ABCDEF"}} | .position="left" | del(.components)' "$root/astral-bar/settings.json" > "$scratch/old-bar"
cp -- "$scratch/old-bar" "$root/astral-bar/settings.json"
rm -- "$root/settings.json"
install_config
jq -e '.scale==1.5 and .colors.dark.cyan=="#ABCDEF" and (.modules|type)=="array"' "$root/settings.json" >/dev/null
jq -e '.position=="left" and (has("colors")|not) and .components.audio==""' "$root/astral-bar/settings.json" >/dev/null
backup=$(find "$root/.backups" -name settings.json -path '*/astral-bar/*' | head -1)
cmp -- "$scratch/old-bar" "$backup"
# The older stock entry escaped its common imports; migrate it even if code matches.
jq '(.modules[] | select(.id == "astral-bar") | .path) = "astral-bar"' "$root/settings.json" > "$scratch/old-entry"
cp -- "$scratch/old-entry" "$root/settings.json"
install_config
jq -e '.modules[] | select(.id == "astral-bar") | .path == "bar.qml"' "$root/settings.json" >/dev/null
# Reapply preserves edited common settings and a custom registry.
jq '.providers.launcher=["/a path/launcher","literal;$(test)"] | .modules += [{id:"external",path:"/a path/main.qml",enabled:false,autostart:true}]' "$root/settings.json" > "$scratch/custom"
cp -- "$scratch/custom" "$root/settings.json"
install_config
cmp -- "$scratch/custom" "$root/settings.json"
# Partial built-in installation includes the root dependencies exactly once.
install_config --name partial --module astral-bar
[[ -f $root/partial/common/Theme.qml && -f $root/partial/settings.json && ! -d $root/partial/astral-lock ]]
# External replacements need only a QML entry. A path containing shell syntax
# must be passed literally, and must never execute it.
external="$scratch/source with spaces; literal"
mkdir -p -- "$external"
printf 'import QtQuick\nItem {}\n' > "$external/shell.qml"
install_config --name external --module astral-bar --source "$external"
cmp -- "$external/shell.qml" "$root/external/astral-bar/shell.qml"
[[ ! -e $root/external/astral-bar/settings.json && -f $root/external/common/Theme.qml ]]
install_config --name external-file --module custom --source "$external/shell.qml"
[[ -f $root/external-file/custom/shell.qml ]]
jq -e '(.modules | length)==1 and (.modules | any(.id=="custom" and .autostart==false))' "$root/external-file/settings.json" >/dev/null
# Named command dispatch embeds the selected destination, including spaces.
mkdir -p -- "$scratch/bin"
cat > "$scratch/bin/qs" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ASTRAL_ARGS"
MOCK
chmod 755 "$scratch/bin/qs"
export PATH=$scratch/bin:$PATH ASTRAL_ARGS=$scratch/args
"$HOME/.local/bin/astral-shell" --no-color --verbose
[[ $(tail -n 2 "$scratch/args") == $'--no-color\n--verbose' ]]
rg -q -F "$root/external-file/shell.qml" "$scratch/args"
"$HOME/.local/bin/astral-bar" start
rg -q -F "$root/external/astral-bar/shell.qml" "$scratch/args"
# Existing old settings in the root also migrate on a partial apply.
mkdir -p -- "$root/legacy"
printf '{"scale":2,"position":"right","modules":{"audio":false}}\n' > "$root/legacy/settings.json"
install_config --name legacy --module astral-bar
jq -e '.scale==2' "$root/legacy/settings.json" >/dev/null
jq -e '.position=="right" and .modules.audio==false' "$root/legacy/astral-bar/settings.json" >/dev/null
# Wallpaper partial installation, migration of an absent registry entry, and external replacement.
install_config --name wallpaper-only --module astral-wallpaper
jq -e '(.modules | length)==1 and .modules[0].id=="astral-wallpaper" and .modules[0].path=="wallpaper.qml"' "$root/wallpaper-only/settings.json" >/dev/null
[[ -x $HOME/.local/bin/astral-wallpaper && -f $root/wallpaper-only/wallpaper-control.qml ]]
jq '.modules |= map(select(.id != "astral-wallpaper"))' "$root/settings.json" > "$scratch/without-wallpaper"
cp "$scratch/without-wallpaper" "$root/settings.json"
install_config
jq -e '.modules | any(.id=="astral-wallpaper" and .autostart)' "$root/settings.json" >/dev/null
jq '(.modules[] | select(.id=="astral-wallpaper")) |= (.enabled=false | .path="/external/main.qml")' "$root/settings.json" > "$scratch/disabled-wallpaper"
cp "$scratch/disabled-wallpaper" "$root/settings.json"
install_config
cmp "$scratch/disabled-wallpaper" "$root/settings.json"
install_config --name wallpaper-external --module astral-wallpaper --source "$external/shell.qml"
[[ ! -e $root/wallpaper-external/astral-wallpaper/settings.json ]]
jq -e '.modules[0].path=="astral-wallpaper/shell.qml"' "$root/wallpaper-external/settings.json" >/dev/null
"$HOME/.local/bin/astral-wallpaper" 'DP-1'
rg -qF "$root/wallpaper-external/wallpaper-control.qml" "$scratch/args"
install_config --name launcher-only --module astral-launcher
jq -e '(.modules | length)==1 and .modules[0].id=="astral-launcher" and .modules[0].path=="launcher.qml"' "$root/launcher-only/settings.json" >/dev/null
[[ -f $root/launcher-only/launcher-control.qml && -x $HOME/.local/bin/astral-launcher ]]
install_config --name launcher-external --module astral-launcher --source "$external/shell.qml"
jq -e '.modules[0].path=="astral-launcher/shell.qml"' "$root/launcher-external/settings.json" >/dev/null
"$HOME/.local/bin/astral-launcher" 'DP with spaces;$(literal)'
rg -qF "$root/launcher-external/launcher-control.qml" "$scratch/args"
jq '.modules |= map(select(.id != "astral-launcher"))' "$root/settings.json" > "$scratch/without-launcher"
cp "$scratch/without-launcher" "$root/settings.json"
install_config
jq -e '.modules | any(.id=="astral-launcher" and .autostart)' "$root/settings.json" >/dev/null

install_config --name polkit-only --module astral-polkit
jq -e '(.modules | length)==1 and .modules[0].id=="astral-polkit" and .modules[0].path=="polkit.qml" and .modules[0].autostart' "$root/polkit-only/settings.json" >/dev/null
[[ -f $root/polkit-only/polkit-control.qml && -x $HOME/.local/bin/astral-polkit ]]
install_config --name polkit-external --module astral-polkit --source "$external/shell.qml"
jq -e '.modules[0].path=="astral-polkit/shell.qml"' "$root/polkit-external/settings.json" >/dev/null
"$HOME/.local/bin/astral-polkit" status
rg -qF "$root/polkit-external/polkit-control.qml" "$scratch/args"
jq '(.modules[] | select(.id=="astral-polkit")) |= (.enabled=false | .path="/external/auth.qml")' "$root/settings.json" > "$scratch/disabled-polkit"
cp "$scratch/disabled-polkit" "$root/settings.json"
install_config
cmp "$scratch/disabled-polkit" "$root/settings.json"
# Missing registry entries are restored without changing existing preferences.
jq '.modules |= map(select(.id != "astral-polkit"))' "$root/settings.json" > "$scratch/no-polkit"
cp "$scratch/no-polkit" "$root/settings.json"
install_config
jq -e '.modules | any(.id=="astral-polkit" and .enabled and .autostart)' "$root/settings.json" >/dev/null
cp "$root/settings.json" "$scratch/reapplied-polkit"
install_config
cmp "$scratch/reapplied-polkit" "$root/settings.json"
install_config --name lock-only --module astral-lock
jq -e '(.modules | length)==2 and (.modules | any(.id=="astral-lock" and .path=="lock.qml" and (.autostart|not))) and (.modules | any(.id=="astral-idle" and .autostart)) and .providers.lock==["astral-lock","lock"]' "$root/lock-only/settings.json" >/dev/null
[[ -f $root/lock-only/lock-control.qml && -f $root/lock-only/common/SessionHint.qml && -x $HOME/.local/bin/astral-lock ]]
install_config --name session-only --module astral-session
jq -e '(.modules | length)==1 and .modules[0].id=="astral-session" and .modules[0].path=="session.qml" and .providers.lock==[]' "$root/session-only/settings.json" >/dev/null
[[ -x $HOME/.local/bin/astral-session && ! -e $root/session-only/astral-lock ]]
install_config --name lock-external --module astral-lock --source "$external/shell.qml"
jq -e '(.modules | length)==1 and .modules[0].path=="astral-lock/shell.qml" and (.modules[0].autostart|not)' "$root/lock-external/settings.json" >/dev/null
"$HOME/.local/bin/astral-lock" lock
rg -qF "$root/lock-external/lock-control.qml" "$scratch/args"
install_config --name session-external --module astral-session --source "$external/shell.qml"
jq -e '.modules[0].path=="astral-session/shell.qml"' "$root/session-external/settings.json" >/dev/null
"$HOME/.local/bin/astral-session" toggle
rg -qF "$root/session-external/session-control.qml" "$scratch/args"
# Reapplying preserves intentionally disabled providers and replacement entries.
jq '.providers.lock=[] | (.modules[] | select(.id=="astral-lock")) |= (.enabled=false | .path="/custom/lock.qml")' "$root/settings.json" > "$scratch/custom-lock"
cp "$scratch/custom-lock" "$root/settings.json"
install_config
cmp "$scratch/custom-lock" "$root/settings.json"
# Shared workspace and old module preferences migrate once; root remains authoritative.
jq 'del(.workspaceCount, .clipboard, .overview)' "$root/settings.json" > "$scratch/old-common"
cp "$scratch/old-common" "$root/settings.json"
jq '.workspaceCount=7' "$root/astral-bar/settings.json" > "$scratch/old-count"
cp "$scratch/old-count" "$root/astral-bar/settings.json"
printf '{"historySize":23,"enterAction":"copy"}\n' > "$root/astral-clipboard/settings.json"
printf '{"previews":false}\n' > "$root/astral-overview/settings.json"
install_config
jq -e '.workspaceCount==7 and .clipboard.historySize==23 and .clipboard.enterAction=="copy" and .overview.previews==false' "$root/settings.json" >/dev/null
jq -e 'has("workspaceCount")|not' "$root/astral-bar/settings.json" >/dev/null
[[ $("$HOME/.local/bin/astral-bar" workspace-count) == 7 ]]
for panel in clipboard overview shortcuts; do
  install_config --name "$panel-only" --module "astral-$panel"
  jq -e --arg id "astral-$panel" '(.modules | length)==1 and .modules[0].id==$id and .modules[0].autostart' "$root/$panel-only/settings.json" >/dev/null
  [[ -x $HOME/.local/bin/astral-$panel && -f $root/$panel-only/$panel-control.qml ]]
  install_config --name "$panel-external" --module "astral-$panel" --source "$external/shell.qml"
  jq -e --arg path "astral-$panel/shell.qml" '.modules[0].path==$path' "$root/$panel-external/settings.json" >/dev/null
  "$HOME/.local/bin/astral-$panel" toggle
  rg -qF "$root/$panel-external/$panel-control.qml" "$scratch/args"
done
printf 'QUICKSHELL_INSTALL_PASS\n'
