#!/usr/bin/env bash

module_destination() { printf '%s/gtk-4.0\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == gtk-4.0 ]] || [[ -f $path && $name == settings.ini ]]
}
