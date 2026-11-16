#!/usr/bin/env bash

module_destination() { printf '%s/fish\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == fish ]] || [[ -f $path && $name == config.fish ]]
}
