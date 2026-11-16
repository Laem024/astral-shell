#!/usr/bin/env bash

module_destination() { printf '%s/kitty\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == kitty ]] || [[ -f $path && $name == kitty.conf ]]
}
