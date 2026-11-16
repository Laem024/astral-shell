#!/usr/bin/env bash

module_destination() { printf '%s/qt5ct\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == qt5ct ]] || [[ -f $path && $name == qt5ct.conf ]]
}
