#!/usr/bin/env bash

module_destination() { printf '%s/qt6ct\n' "$1"; }

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == qt6ct ]] || [[ -f $path && $name == qt6ct.conf ]]
}
