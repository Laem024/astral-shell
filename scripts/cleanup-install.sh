#!/usr/bin/env bash
# Shared scratch space for one installation; never scan for old files.

astral_install_check_path() {
  local path=$1 current=/ part
  [[ $path == /* && $path == "$(realpath -ms -- "$path")" ]] || return 1
  path=${path#/}
  while [[ -n $path ]]; do
    part=${path%%/*}
    if [[ $path == */* ]]; then path=${path#*/}; else path=''; fi
    current=${current%/}/$part
    [[ ! -L $current ]] || return 1
  done
}

astral_install_root() {
  local root=${XDG_CACHE_HOME:-$HOME/.cache}/astral-shell/install
  astral_install_check_path "$root" || return 1
  printf '%s\n' "$root"
}

astral_install_validate() {
  local directory=$1 root
  [[ $EUID != 0 ]] || return 1
  root=$(astral_install_root) || return 1
  [[ ${directory%/*} == "$root" && ${directory##*/} =~ ^run-[a-zA-Z0-9]{8}$ ]] || return 1
  astral_install_check_path "$directory" || return 1
  [[ -d $root && -O $root && $(stat -c %a -- "$root") == 700 ]] || return 1
  [[ -d $directory && -O $directory && $(stat -c %a -- "$directory") == 700 ]] || return 1
  [[ -f $directory/.astral-install && ! -L $directory/.astral-install && -O $directory/.astral-install ]] || return 1
  [[ $(cat -- "$directory/.astral-install") == astral-install-v1 ]]
}

astral_install_begin() {
  local root
  [[ $EUID != 0 ]] || { printf 'Run installation as a regular user.\n' >&2; return 1; }
  root=$(astral_install_root) || return 1
  (umask 077; mkdir -p -- "$root") || return 1
  [[ -d $root && -O $root && $(stat -c %a -- "$root") == 700 ]] || return 1
  ASTRAL_INSTALL_WORKDIR=$(mktemp -d -- "$root/run-XXXXXXXX") || return 1
  printf 'astral-install-v1\n' > "$ASTRAL_INSTALL_WORKDIR/.astral-install"
  export ASTRAL_INSTALL_WORKDIR
}

# Keep standalone installers' existing temporary locations. During install.sh,
# only explicitly allocated scratch files are redirected to this run's folder.
astral_install_mktemp() {
  if [[ -z ${ASTRAL_INSTALL_WORKDIR:-} ]]; then
    mktemp "$@"
    return
  fi
  astral_install_validate "$ASTRAL_INSTALL_WORKDIR" || {
    printf 'Invalid Astral installation scratch directory.\n' >&2
    return 1
  }
  if [[ ${1:-} == -d ]]; then
    mktemp -d -- "$ASTRAL_INSTALL_WORKDIR/scratch-XXXXXXXX"
  else
    mktemp -- "$ASTRAL_INSTALL_WORKDIR/scratch-XXXXXXXX"
  fi
}

astral_install_cleanup() {
  local directory=$1
  astral_install_validate "$directory" || {
    printf 'Refusing to clean an unverified Astral installation directory: %s\n' "$directory" >&2
    return 1
  }
  rm -rf --one-file-system -- "$directory"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  set -euo pipefail
  [[ $# == 1 ]] || { printf 'Usage: cleanup-install.sh RUN_DIRECTORY\n' >&2; exit 2; }
  astral_install_cleanup "$1"
fi
