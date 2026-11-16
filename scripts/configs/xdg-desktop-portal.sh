#!/usr/bin/env bash

module_destination() { printf '%s/xdg-desktop-portal\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == xdg-desktop-portal ]] || [[ -f $path && $name == portals.conf ]]
}
