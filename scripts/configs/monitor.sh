#!/usr/bin/env bash

module_destination() {
  printf '%s/astral-monitor\n' "$1"
}

module_candidate() {
  local path=$1 name=${1##*/}
  [[ -d $path && $name == monitor ]] || [[ -f $path && $name == btop.conf ]]
}

module_install_command() {
  local body
  body=$(printf 'exec bash %q "$@"' "$destination/astral-monitor.sh")
  install_public_command astral-monitor "$body"
}
