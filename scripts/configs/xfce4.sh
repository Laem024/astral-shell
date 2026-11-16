#!/usr/bin/env bash

module_destination() { printf '%s/xfce4\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == xfce4 ]] || [[ -f $path && $name == thunar.xml ]]
}
