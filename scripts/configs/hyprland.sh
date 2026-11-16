#!/usr/bin/env bash

module_destination() { printf '%s/hypr\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && ( $name == hypr || $name == hyprland ) ]] \
    || [[ -f $path && ( $name == hyprland.conf || $name == hyprland.lua ) ]]
}

# Only retire byte-identical project files; custom copies require manual review.
module_retired_files() {
  local name digest target
  while read -r digest name; do
    target=$destination/$name
    [[ -e $target || -L $target ]] || continue
    if [[ -f $target && ! -L $target && $(sha256sum < "$target") == "$digest  -" ]]; then
      retired_files+=("$name")
    else
      printf 'Preserve customized retired file; review manually: %q\n' "$target"
    fi
  done <<'RETIRED'
4b2e10162a5726fd1d4d94ba9d812afecc5e9ae610725d11183472f5d363d596 start-idle.sh
ed255c48729ceda4dd25f2f59123c95a7312de332f05e6ba74a9559b11385a5f hypridle.conf
RETIRED
}
