#!/usr/bin/env bash

module_destination() { printf '%s/quickshell%s\n' "$1" "${2:+/$2}"; }
module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == quickshell ]] || [[ -f $path && $name == shell.qml ]]
}
module_names=(astral-bar astral-wallpaper astral-launcher astral-polkit astral-lock astral-session astral-clipboard astral-overview astral-shortcuts)
module_commands_by_module() {
  local name
  printf '%s\n' astral-shell
  for name in astral-lock astral-session astral-clipboard astral-overview astral-shortcuts; do
    if [[ -f $source_path/$name/shell.qml || -f $quickshell_destination/$name/shell.qml ]]; then printf '%s\n' "$name"; fi
  done
  if [[ -f $source_path/astral-launcher/shell.qml || -f $quickshell_destination/astral-launcher/shell.qml ]]; then printf '%s\n' astral-launcher; fi
  if [[ -f $source_path/astral-polkit/shell.qml || -f $quickshell_destination/astral-polkit/shell.qml ]]; then printf '%s\n' astral-polkit; fi
  if [[ -f $source_path/astral-wallpaper/shell.qml || -f $quickshell_destination/astral-wallpaper/shell.qml ]]; then printf '%s\n' astral-wallpaper; fi
  if [[ -f $source_path/astral-bar/shell.qml || -f $quickshell_destination/astral-bar/shell.qml ]]; then printf '%s\n' astral-bar; fi
}
module_command_body() {
  case $1 in
    astral-clipboard|astral-overview|astral-shortcuts)
      local short=${1#astral-}
      printf 'export ASTRAL_%s_CONTROLLER=%q\nexec bash %q %q %q "$@"\n' "${short^^}" "$module_root/$short-control.qml" "$module_root/dispatch.sh" "$module_root/$short.qml" "$short"
      ;;
    astral-shell) printf 'export ASTRAL_COMMON_SETTINGS=%q\nexec bash %q %q shell "$@"\n' "$module_root/settings.json" "$module_root/dispatch.sh" "$module_root/shell.qml" ;;
    astral-lock) printf 'export ASTRAL_LOCK_CONTROLLER=%q\nexec bash %q %q lock "$@"\n' "$module_root/lock-control.qml" "$module_root/dispatch.sh" "$module_root/lock.qml" ;;
    astral-session) printf 'export ASTRAL_SESSION_CONTROLLER=%q\nexec bash %q %q session "$@"\n' "$module_root/session-control.qml" "$module_root/dispatch.sh" "$module_root/session.qml" ;;
    astral-launcher) printf 'export ASTRAL_LAUNCHER_CONTROLLER=%q\nexec bash %q %q launcher "$@"\n' "$module_root/launcher-control.qml" "$module_root/dispatch.sh" "${launcher_entry:-$module_root/launcher.qml}" ;;
    astral-polkit) printf 'export ASTRAL_POLKIT_CONTROLLER=%q\nexec bash %q %q polkit "$@"\n' "$module_root/polkit-control.qml" "$module_root/dispatch.sh" "${polkit_entry:-$module_root/polkit.qml}" ;;
    astral-wallpaper) printf 'export ASTRAL_WALLPAPER_CONTROLLER=%q\nexec bash %q %q wallpaper "$@"\n' "$module_root/wallpaper-control.qml" "$module_root/dispatch.sh" "${wallpaper_entry:-$module_root/wallpaper.qml}" ;;
    astral-bar) printf 'export ASTRAL_COMMON_SETTINGS=%q\nexec bash %q %q "$@"\n' "$module_root/settings.json" "$module_root/dispatch.sh" "${bar_entry:-$module_root/bar.qml}" ;;
  esac
}
module_install_command() {
  local name
  bar_entry=$module_root/bar.qml
  if [[ -f $quickshell_destination/settings.json ]]; then
    local configured
    configured=$(jq -r '.modules[] | select(.id == "astral-bar") | .path' "$quickshell_destination/settings.json")
    if [[ -n $configured ]]; then
      [[ $configured == /* ]] && bar_entry=$configured || bar_entry=$module_root/$configured
      [[ $bar_entry == *.qml ]] || bar_entry+=/shell.qml
    fi
  fi
  wallpaper_entry=$module_root/wallpaper.qml
  if [[ -f $quickshell_destination/settings.json ]]; then
    local configured_wallpaper
    configured_wallpaper=$(jq -r '.modules[] | select(.id == "astral-wallpaper") | .path' "$quickshell_destination/settings.json")
    if [[ -n $configured_wallpaper ]]; then
      [[ $configured_wallpaper == /* ]] && wallpaper_entry=$configured_wallpaper || wallpaper_entry=$module_root/$configured_wallpaper
      [[ $wallpaper_entry == *.qml ]] || wallpaper_entry+=/shell.qml
    fi
  fi
  launcher_entry=$module_root/launcher.qml
  if [[ -f $quickshell_destination/settings.json ]]; then
    local configured_launcher
    configured_launcher=$(jq -r '.modules[] | select(.id == "astral-launcher") | .path' "$quickshell_destination/settings.json")
    if [[ -n $configured_launcher ]]; then
      [[ $configured_launcher == /* ]] && launcher_entry=$configured_launcher || launcher_entry=$module_root/$configured_launcher
      [[ $launcher_entry == *.qml ]] || launcher_entry+=/shell.qml
    fi
  fi
  polkit_entry=$module_root/polkit.qml
  if [[ -f $quickshell_destination/settings.json ]]; then
    local configured_polkit
    configured_polkit=$(jq -r '.modules[] | select(.id == "astral-polkit") | .path' "$quickshell_destination/settings.json")
    if [[ -n $configured_polkit ]]; then
      [[ $configured_polkit == /* ]] && polkit_entry=$configured_polkit || polkit_entry=$module_root/$configured_polkit
      [[ $polkit_entry == *.qml ]] || polkit_entry+=/shell.qml
    fi
  fi
  check_directory "$HOME/.local/bin"
  while IFS= read -r name; do install_public_command "$name" "$(module_command_body "$name")"; done < <(module_commands_by_module)
}
module_settings_missing() {
  check_components "$quickshell_destination/settings.json"
  check_components "$quickshell_destination/astral-bar/settings.json"
  [[ ! -f $quickshell_destination/settings.json ]] && return 0
  jq -e 'has("workspaceCount") and has("clipboard") and has("overview")' "$quickshell_destination/settings.json" >/dev/null || return 0
  local module
  for module in astral-lock astral-session astral-clipboard astral-overview astral-shortcuts; do
    if [[ -f $source_path/$module/shell.qml ]] && ! jq -e --arg id "$module" '.modules | any(.id == $id)' "$quickshell_destination/settings.json" >/dev/null; then return 0; fi
  done
  if [[ -f $source_path/astral-lock/IdleService.qml ]] && ! jq -e '.modules | any(.id == "astral-idle")' "$quickshell_destination/settings.json" >/dev/null; then return 0; fi
  [[ -f $source_path/astral-bar/settings.json && ! -f $quickshell_destination/astral-bar/settings.json ]] && return 0
  if [[ -f $source_path/astral-bar/BarRoot.qml ]] && jq -e '.modules | type == "array" and any(.[]; .id == "astral-bar" and (.path == "astral-bar" or .path == "astral-bar/shell.qml"))' "$quickshell_destination/settings.json" >/dev/null; then return 0; fi
  # An existing module-local settings file may still carry the old common keys.
  if [[ -f $quickshell_destination/astral-bar/settings.json ]] && jq -e 'has("colors") or (.components == null)' "$quickshell_destination/astral-bar/settings.json" >/dev/null; then return 0; fi
  jq -e '.modules | type == "array"' "$quickshell_destination/settings.json" >/dev/null || return 0
  if [[ -f $source_path/astral-wallpaper/shell.qml ]] && ! jq -e '.modules | any(.id == "astral-wallpaper")' "$quickshell_destination/settings.json" >/dev/null; then return 0; fi
  if [[ -f $source_path/astral-launcher/shell.qml ]] && ! jq -e '.modules | any(.id == "astral-launcher")' "$quickshell_destination/settings.json" >/dev/null; then return 0; fi
  if [[ -f $source_path/astral-polkit/shell.qml ]] && ! jq -e '.modules | any(.id == "astral-polkit")' "$quickshell_destination/settings.json" >/dev/null; then return 0; fi
  return 1
}
module_merge_settings() {
  local source=$1 legacy=$2 target=$3
  jq -n --slurpfile base "$source" --slurpfile legacy "$legacy" '
    def merge($base; $over):
      if ($base|type) == "object" then
        ($base | to_entries | map(.key as $k | .value = merge(.value; (if ($over|type) == "object" then $over[$k] else null end))) | from_entries)
      elif $over != null and ($over|type) == ($base|type) then $over else $base end;
    merge($base[0]; $legacy[0])
  ' > "$target"
}
module_prepare_settings() {
  local root=$quickshell_destination common=$quickshell_destination/settings.json bar=$quickshell_destination/astral-bar/settings.json
  local merged temporary existing base
  check_components "$common"
  check_components "$bar"
  command -v jq >/dev/null || die 'Settings migration requires jq.'
  # apply_configs has already backed up the entire destination, including old preferences.
  # The dry run returns before this function and never creates a staging file here.
  mkdir -p -- "$root"
  merged=$(mktemp "$root/.preferences-XXXXXX")
  temporary=$(mktemp "$root/.settings-XXXXXX")
  existing=$(mktemp "$root/.existing-XXXXXX")
  printf '{}\n' > "$merged"
  if [[ -f $bar ]]; then jq -s '.[0] * .[1]' "$merged" "$bar" > "$existing"; cp -- "$existing" "$merged"; fi
  if [[ -f $common ]]; then jq -s '.[0] * .[1]' "$merged" "$common" > "$existing"; cp -- "$existing" "$merged"; fi
  # Import old module-local preferences only when the root does not own them.
  local preference
  for preference in clipboard overview; do
    if [[ -f $root/astral-$preference/settings.json ]]; then
      jq --arg key "$preference" --slurpfile local "$root/astral-$preference/settings.json" '
        if has($key) then . else .[$key] = ($local[0] | if $key == "clipboard" then {historySize,enterAction,pasteShortcut,maxImageBytes} else {previews} end | with_entries(select(.value != null))) end
      ' "$merged" > "$existing"
      cp -- "$existing" "$merged"
    fi
  done
  module_merge_settings "$source_path/settings.json" "$merged" "$temporary"
  # Only install built-in providers when their module is available. Existing
  # provider arrays, including intentional empty arrays, remain authoritative.
  local has_lock=false has_session=false has_idle=false
  [[ ! -f $source_path/astral-lock/shell.qml && ! -f $root/astral-lock/shell.qml ]] || has_lock=true
  [[ ! -f $source_path/astral-session/shell.qml && ! -f $root/astral-session/shell.qml ]] || has_session=true
  [[ ! -f $source_path/astral-lock/IdleService.qml && ! -f $root/astral-lock/IdleService.qml ]] || has_idle=true
  jq --argjson idle "$has_idle" --argjson lock "$has_lock" --argjson session "$has_session" --slurpfile old "$merged" '
    .modules |= map(select((.id != "astral-lock" or $lock) and (.id != "astral-idle" or $idle) and (.id != "astral-session" or $session))) |
    if $lock then . else .providers |= with_entries(if .key != "launcher" and $old[0].providers[.key] == null then .value=[] else . end) end
  ' "$temporary" > "$existing"
  cp -- "$existing" "$temporary"
  local available='[]' candidate
  for candidate in "${module_names[@]}"; do
    if [[ -f $source_path/$candidate/shell.qml || -f $root/$candidate/shell.qml ]]; then
      available=$(jq --arg id "$candidate" '. + [$id]' <<< "$available")
    fi
  done
  jq --argjson available "$available" '.modules |= map(select(.id as $id | (["astral-clipboard","astral-overview","astral-shortcuts"] | index($id) | not) or ($available | index($id))))' "$temporary" > "$existing"
  cp -- "$existing" "$temporary"
  # Fresh partial installations register only modules whose entries are present.
  if [[ ! -f $common ]]; then
    local has_bar=false has_wallpaper=false has_launcher=false has_polkit=false
    [[ ! -f $source_path/astral-bar/shell.qml && ! -f $root/astral-bar/shell.qml ]] || has_bar=true
    [[ ! -f $source_path/astral-wallpaper/shell.qml && ! -f $root/astral-wallpaper/shell.qml ]] || has_wallpaper=true
    [[ ! -f $source_path/astral-launcher/shell.qml && ! -f $root/astral-launcher/shell.qml ]] || has_launcher=true
    [[ ! -f $source_path/astral-polkit/shell.qml && ! -f $root/astral-polkit/shell.qml ]] || has_polkit=true
    jq --argjson polkit "$has_polkit" --argjson launcher "$has_launcher" --argjson bar "$has_bar" --argjson wallpaper "$has_wallpaper" '.modules |= map(select((.id != "astral-bar" or $bar) and (.id != "astral-wallpaper" or $wallpaper) and (.id != "astral-launcher" or $launcher) and (.id != "astral-polkit" or $polkit)))' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  if [[ -f $source_path/astral-wallpaper/shell.qml ]]; then
    local wallpaper_path=wallpaper.qml
    [[ $selected_module != astral-wallpaper || -z $module_source ]] || wallpaper_path=astral-wallpaper/shell.qml
    jq --arg path "$wallpaper_path" '.modules |= (if any(.[]; .id == "astral-wallpaper") then map(if .id == "astral-wallpaper" and (.path == "astral-wallpaper" or .path == "astral-wallpaper/shell.qml" or .path == "wallpaper.qml") then .path=$path else . end) else . + [{id:"astral-wallpaper",path:$path,enabled:true,autostart:true}] end)' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  if [[ -f $source_path/astral-launcher/shell.qml ]]; then
    local launcher_path=launcher.qml
    [[ $selected_module != astral-launcher || -z $module_source ]] || launcher_path=astral-launcher/shell.qml
    jq --arg path "$launcher_path" '.modules |= (if any(.[]; .id == "astral-launcher") then map(if .id == "astral-launcher" and (.path == "astral-launcher" or .path == "astral-launcher/shell.qml" or .path == "launcher.qml") then .path=$path else . end) else . + [{id:"astral-launcher",path:$path,enabled:true,autostart:true}] end)' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  if [[ -f $source_path/astral-polkit/shell.qml ]]; then
    local polkit_path=polkit.qml
    [[ $selected_module != astral-polkit || -z $module_source ]] || polkit_path=astral-polkit/shell.qml
    jq --arg path "$polkit_path" '.modules |= (if any(.[]; .id == "astral-polkit") then map(if .id == "astral-polkit" and (.path == "astral-polkit" or .path == "astral-polkit/shell.qml" or .path == "polkit.qml") then .path=$path else . end) else . + [{id:"astral-polkit",path:$path,enabled:true,autostart:true}] end)' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  local module entry autostart
  for module in astral-lock astral-session astral-clipboard astral-overview astral-shortcuts; do
    [[ -f $source_path/$module/shell.qml ]] || continue
    entry=${module#astral-}.qml
    autostart=true
    [[ $module != astral-lock ]] || autostart=false
    [[ $selected_module != "$module" || -z $module_source ]] || entry=$module/shell.qml
    jq --arg id "$module" --arg path "$entry" --argjson autostart "$autostart" '
      .modules |= (if any(.[]; .id == $id) then
        map(if .id == $id and (.path == $id or .path == ($id + "/shell.qml") or .path == (($id | ltrimstr("astral-")) + ".qml")) then .path=$path else . end)
        else . + [{id:$id,path:$path,enabled:true,autostart:$autostart}] end)
    ' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  done
  if [[ -f $source_path/astral-lock/IdleService.qml ]]; then
    jq '.modules |= (if any(.[]; .id == "astral-idle") then . else . + [{id:"astral-idle",path:"idle.qml",enabled:true,autostart:true}] end)' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  # Older migration snapshots launched the stock bar below its shared imports.
  # Keep external replacements on their own entry, and stock bars at the root.
  if [[ -f $source_path/astral-bar/BarRoot.qml || $selected_module == astral-bar ]]; then
    local bar_path=bar.qml
    if [[ $selected_module == astral-bar && -n $module_source ]]; then bar_path=astral-bar/shell.qml; fi
    jq --arg path "$bar_path" '.modules |= map(if .id == "astral-bar" and (.path == "astral-bar" or .path == "astral-bar/shell.qml" or .path == "bar.qml") then .path=$path else . end)' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  # Preserve an existing registry and provider extensions. A legacy visibility map
  # has a different type, so module_merge_settings keeps the new registry default.
  if [[ -n $selected_module && ! " ${module_names[*]} " == *" $selected_module "* ]]; then
    jq --arg id "$selected_module" '.modules |= (if any(.[]; .id == $id) then . else . + [{id:$id,path:$id,enabled:true,autostart:false}] end)' "$temporary" > "$existing"
    cp -- "$existing" "$temporary"
  fi
  chmod 600 "$temporary"
  if [[ ! -f $common ]] || ! cmp -s -- "$temporary" "$common"; then mv -- "$temporary" "$common"; else rm -- "$temporary"; fi
  if [[ -f $source_path/astral-bar/settings.json ]]; then
    if [[ -f $bar ]]; then cp -- "$bar" "$existing"; else cp -- "$merged" "$existing"; fi
    module_merge_settings "$source_path/astral-bar/settings.json" "$existing" "$temporary"
    mkdir -p -- "${bar%/*}"
    chmod 600 "$temporary"
    if [[ ! -f $bar ]] || ! cmp -s -- "$temporary" "$bar"; then mv -- "$temporary" "$bar"; else rm -- "$temporary"; fi
  fi
  rm -f -- "$merged" "$temporary" "$existing"
}

module_settings_plan() {
  printf 'Preserve or migrate common preferences: %q\n' "$quickshell_destination/settings.json"
  if [[ -f $source_path/astral-bar/settings.json ]]; then
    printf 'Preserve or migrate bar preferences: %q\n' "$quickshell_destination/astral-bar/settings.json"
  fi
}
