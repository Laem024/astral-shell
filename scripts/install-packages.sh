#!/usr/bin/env bash
set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
cancel() { printf '\nInstallation canceled.\n'; exit 130; }
trap cancel INT TERM
ROOT=${1:?Missing project directory}
mode=${2:-install}
[[ $# -le 2 && ( $mode == install || $mode == update ) ]] || die 'Expected project directory and install or update.'
[[ $EUID -ne 0 ]] || die 'Run install.sh as a regular user, without sudo.'
[[ -t 0 && -t 1 ]] || die 'An interactive terminal is required.'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/package-menu.sh"
for tool in pacman sudo fold; do
  command -v "$tool" >/dev/null || die "Required command not found: $tool."
done

declare -a sources=() categories=() levels=() packages=() descriptions=() dependencies=()
declare -a chosen=() effective=() locked=() reasons=() category_order=() visit=()
declare -a screen_indices=()
declare -A seen=() known_categories=() native_index=() associated=()
helper_rows=0
navigation=''

trim() {
  REPLY=${1#"${1%%[![:space:]]*}"}
  REPLY=${REPLY%"${REPLY##*[![:space:]]}"}
}

load_catalog() {
  local source=$1 file="$ROOT/packages/$1.list" line body comment category level package deps bars key
  local number=0
  [[ -r $file ]] || die "Cannot read $file."
  while IFS= read -r line || [[ -n $line ]]; do
    number=$((number + 1))
    trim "$line"; line=$REPLY
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *'#'* ]] || die "$file:$number: missing purpose comment."
    body=${line%%#*}; comment=${line#*#}
    bars=${body//[^|]/}
    [[ ${#bars} -eq 2 || ${#bars} -eq 3 ]] || die "$file:$number: expected three or four fields."
    IFS='|' read -r category level package deps <<< "$body"
    trim "$category"; category=$REPLY
    trim "$level"; level=$REPLY
    trim "$package"; package=$REPLY
    trim "${deps:-}"; deps=$REPLY
    trim "$comment"; comment=$REPLY
    [[ -n $category && -n $comment ]] || die "$file:$number: empty category or purpose."
    case $level in
      required|recommended|optional) ;;
      *) die "$file:$number: invalid status '$level'; use required, recommended or optional." ;;
    esac
    if [[ $package == '@aur-helper@' ]]; then
      [[ $source == pacman && $level == required ]] || die "$file:$number: invalid AUR helper placeholder."
      helper_rows=$((helper_rows + 1))
    elif [[ $source == flatpak ]]; then
      [[ $package =~ ^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$ ]] || die "$file:$number: invalid Flatpak ID."
    else
      [[ $package =~ ^[a-z0-9@_+][a-z0-9@._+-]*$ ]] || die "$file:$number: invalid package name."
    fi
    if [[ ${#bars} -eq 3 ]]; then
      [[ $deps =~ ^[a-z0-9_+][a-z0-9@._+-]*([[:space:]]*,[[:space:]]*[a-z0-9_+][a-z0-9@._+-]*)*$ ]] \
        || die "$file:$number: invalid or empty dependency list."
    fi
    key="native:$package"
    [[ $source != flatpak ]] || key="flatpak:$package"
    [[ ! ${seen[$key]+exists} ]] || die "$file:$number: duplicate package '$package'."
    seen[$key]=1
    if [[ $source == pacman ]]; then native_index[$package]=${#packages[@]}; fi
    if [[ ! ${known_categories[$category]+exists} ]]; then
      category_order+=("$category"); known_categories[$category]=1
    fi
    sources+=("$source"); categories+=("$category"); levels+=("$level")
    packages+=("$package"); descriptions+=("$comment"); dependencies+=("$deps")
    if [[ $level == optional ]]; then chosen+=(0); else chosen+=(1); fi
    visit+=(0)
  done < "$file"
}

# Every associated package must have a documented pacman entry. Validate the
# graph before asking questions, including references from unselected packages.
validate_dependencies() {
  local index=$1 dep child
  local -a items=()
  [[ ${visit[index]} != 1 ]] || die "Dependency cycle involving '${packages[index]}'."
  [[ ${visit[index]} != 2 ]] || return 0
  visit[index]=1
  IFS=',' read -r -a items <<< "${dependencies[index]}"
  for dep in "${items[@]}"; do
    trim "$dep"; dep=$REPLY
    [[ ${native_index[$dep]+exists} ]] || die "${packages[index]}: dependency '$dep' needs a pacman catalog entry."
    child=${native_index[$dep]}
    validate_dependencies "$child"
  done
  visit[index]=2
}

# Packages referenced by another entry are installed with it and never offered
# as independent choices: the parent's line documents why they are needed.
# Their own entry only supplies the source and purpose shown in Dependencies.
mark_associations() {
  local index dep
  local -a items=()
  for index in "${!packages[@]}"; do
    IFS=',' read -r -a items <<< "${dependencies[index]}"
    for dep in "${items[@]}"; do
      trim "$dep"
      [[ -z $REPLY ]] || associated[$REPLY]=1
    done
  done
  for index in "${!packages[@]}"; do
    [[ ${levels[index]} == required ]] && continue
    [[ -z ${associated[${packages[index]}]+present} ]] || chosen[index]=0
  done
}

for source in pacman aur flatpak; do load_catalog "$source"; done
[[ $helper_rows -eq 1 ]] || die 'pacman.list must contain exactly one required @aur-helper@.'
for i in "${!packages[@]}"; do validate_dependencies "$i"; done
mark_associations

if [[ $mode == update ]] && command -v paru >/dev/null; then
  helper=paru
elif [[ $mode == update ]] && command -v yay >/dev/null; then
  helper=yay
else
  while true; do
    menu_screen
    screen_title 'AUR helper' 'Choose the helper used to install AUR packages.'
    show_notices
    printf '\n  1) paru\n  2) yay\n'
    read -r -p 'Choice [1/2], or quit: ' answer || cancel
    case $answer in
      1|paru) helper=paru; break ;;
      2|yay) helper=yay; break ;;
      quit|cancel|q) cancel ;;
      *) notice 'Enter 1, 2, paru, yay or quit.' ;;
    esac
  done
fi
printf 'AUR helper: %s\n' "$helper"
[[ ! ${seen[native:$helper]+exists} ]] || die 'The chosen helper is already listed; use only @aur-helper@.'
for i in "${!packages[@]}"; do
  [[ ${packages[i]} != '@aur-helper@' ]] || packages[i]=$helper
done

# Keep explicit choices separate from derived selections so removing a parent
# releases its companions without losing independently selected packages.
resolve_selection() {
  local index dep child changed=1
  local -a items=()
  effective=("${chosen[@]}"); locked=(); reasons=()
  for index in "${!packages[@]}"; do
    locked+=(0); reasons+=('')
    if [[ ${levels[index]} == required ]]; then effective[index]=1; locked[index]=1; fi
  done
  while ((changed)); do
    changed=0
    for index in "${!packages[@]}"; do
      [[ ${effective[index]} == 1 ]] || continue
      IFS=',' read -r -a items <<< "${dependencies[index]}"
      for dep in "${items[@]}"; do
        trim "$dep"; child=${native_index[$REPLY]}
        if [[ ${effective[child]} == 0 ]]; then effective[child]=1; changed=1; fi
      done
    done
  done
  for index in "${!packages[@]}"; do
    [[ ${effective[index]} == 1 ]] || continue
    IFS=',' read -r -a items <<< "${dependencies[index]}"
    for dep in "${items[@]}"; do
      trim "$dep"; child=${native_index[$REPLY]}
      locked[child]=1
      reasons[child]+="${reasons[child]:+, }${packages[index]}"
    done
  done
}

collect_level() {
  local level=$1 index
  screen_indices=()
  for index in "${!packages[@]}"; do
    [[ ${levels[index]} == "$level" ]] || continue
    [[ ${levels[index]} == required || -z ${associated[${packages[index]}]+present} ]] || continue
    screen_indices+=("$index")
  done
  return 0
}

count_choices() {
  local index count=0
  for index in "$@"; do
    [[ ${chosen[index]} == 1 ]] && count=$((count + 1))
  done
  REPLY=$count
}

set_required_only() {
  local index
  for index in "${!packages[@]}"; do
    if [[ ${levels[index]} == required ]]; then chosen[index]=1; else chosen[index]=0; fi
  done
}

# Toggle the local IDs shown on the current screen. The complete batch is
# validated before any change, so a typo never leaves a partial selection.
# Locks are resolved again after the batch, so deselecting a parent together
# with its dependents releases the whole group in a single command.
toggle_screen_ids() {
  local input=$1 token position index changed=0 kept=0
  local -a tokens=() unique=() touched=()
  local -A seen_positions=()
  [[ -n ${input//[[:space:]]/} ]] || { notice 'Enter one or more IDs, for example 1 or 1,3,6.'; return 0; }
  read -r -a tokens <<< "${input//,/ }"
  for token in "${tokens[@]}"; do
    [[ -n $token ]] || continue
    if [[ ! $token =~ ^[0-9]+$ ]] || ((${#token} > 6)) || [[ $token =~ ^0+$ ]]; then
      notice 'Invalid package ID: %s. No changes made.' "$token"; return 0
    fi
    position=$((10#$token - 1))
    if ((position < 0 || position >= ${#screen_indices[@]})); then
      notice 'Unknown package ID: %s. No changes made.' "$token"; return 0
    fi
    [[ ${seen_positions[$position]+present} ]] || { unique+=("$position"); seen_positions[$position]=1; }
  done
  for position in "${unique[@]}"; do
    index=${screen_indices[position]}
    if [[ ${chosen[index]} == 1 ]]; then chosen[index]=0; else chosen[index]=1; fi
    touched+=("$index"); changed=$((changed + 1))
  done
  resolve_selection
  for index in "${touched[@]}"; do
    if [[ ${locked[index]} == 1 && ${chosen[index]} == 0 ]]; then
      kept=$((kept + 1))
      notice '%s stays installed: needed by %s.' "${packages[index]}" "${reasons[index]}"
    fi
  done
  if ((changed)); then notice '%d package(s) changed.' "$changed"; fi
  if ((kept)); then notice '%d package(s) kept as dependencies.' "$kept"; fi
}

set_screen_choices() {
  local action=$1 index changed=0 kept=0
  for index in "${screen_indices[@]}"; do
    if [[ $action == all ]]; then
      if [[ ${chosen[index]} == 0 ]]; then chosen[index]=1; changed=$((changed + 1)); fi
    elif [[ ${chosen[index]} == 1 ]]; then
      chosen[index]=0; changed=$((changed + 1))
    fi
  done
  resolve_selection
  if [[ $action == none ]]; then
    for index in "${screen_indices[@]}"; do
      [[ ${locked[index]} == 1 && ${chosen[index]} == 0 ]] && kept=$((kept + 1))
    done
  fi
  if [[ $action == all ]]; then
    notice '%d package(s) selected.' "$changed"
  elif ((kept)); then
    notice '%d package(s) deselected; %d kept as dependencies.' "$changed" "$kept"
  else
    notice '%d package(s) deselected.' "$changed"
  fi
}

screen_required() {
  local answer
  collect_level required
  while true; do
    menu_screen
    screen_title 'Required packages' 'Always installed. These packages cannot be disabled.'
    if ((${#screen_indices[@]})); then
      show_required_table "${screen_indices[@]}"
    else
      printf '  No required packages.\n'
    fi
    show_notices
    printf '\n%sPress Enter to continue, or type cancel to abort.%s\n' "$style_dim" "$style_reset"
    read -r -p 'Continue: ' answer || cancel
    trim "$answer"; answer=$REPLY
    case $answer in
      ''|next|continue|yes|y) navigation=next; return ;;
      cancel|quit|q) cancel ;;
      help|\?) notice '%s' 'This screen is informational. Press Enter to continue or type cancel to abort.' ;;
      *) notice 'Press Enter to continue, or type cancel to abort.' ;;
    esac
  done
}

screen_choices() {
  local level=$1 title=$2 subtitle=$3 answer index selected=0 total
  collect_level "$level"
  total=${#screen_indices[@]}
  if ((total == 0)); then
    while true; do
      menu_screen
      screen_title "$title" "$subtitle"
      printf '  No packages in this group.\n'
      show_notices
      printf '\n%sPress Enter to continue or type back.%s\n' "$style_dim" "$style_reset"
      read -r -p 'Continue: ' answer || cancel
      trim "$answer"; answer=$REPLY
      case $answer in
        ''|next|continue) navigation=next; return ;;
        back) navigation=back; return ;;
        cancel|quit|q) cancel ;;
        *) notice 'Press Enter to continue or type back.' ;;
      esac
    done
  fi
  while true; do
    resolve_selection
    menu_screen
    screen_title "$title" "$subtitle"
    show_choice_table "${screen_indices[@]}"
    count_choices "${screen_indices[@]}"; selected=$REPLY
    printf '\n%s  %d/%d selected%s\n' "$style_dim" "$selected" "$total" "$style_reset"
    show_notices
    printf '\n%sCommands%s  all · none · IDs (1 or 1,3,6) · back · cancel · help\n' \
      "$style_bold" "$style_reset"
    read -r -p 'Choice: ' answer || cancel
    trim "$answer"; answer=$REPLY
    case $answer in
      ''|next|continue) navigation=next; return ;;
      all|none) set_screen_choices "$answer" ;;
      back) navigation=back; return ;;
      cancel|quit|q) cancel ;;
      help|\?)
        notice '%s' 'IDs are local to this screen. Enter one or more separated by commas:
  1        toggle package 1
  1,3,6    toggle packages 1, 3 and 6
  all      select every package on this screen
  none     deselect every package; dependencies stay installed
  back     return to the previous screen
  cancel   abort without changes'
        ;;
      *) toggle_screen_ids "$answer" ;;
    esac
  done
}

screen_dependencies() {
  local answer entry index required_count recommended_count optional_count dependency_count
  local -a dependency_indices=()
  while true; do
    resolve_selection
    build_plan
    dependency_indices=()
    for index in "${!packages[@]}"; do
      [[ ${effective[index]} == 1 && ${locked[index]} == 1 && ${chosen[index]} == 0 ]] \
        && dependency_indices+=("$index")
    done
    required_count=0; recommended_count=0; optional_count=0
    for index in "${!packages[@]}"; do
      [[ ${effective[index]} == 1 ]] || continue
      case ${levels[index]} in
        required) required_count=$((required_count + 1)) ;;
        recommended) [[ ${chosen[index]} == 1 ]] && recommended_count=$((recommended_count + 1)) ;;
        optional) [[ ${chosen[index]} == 1 ]] && optional_count=$((optional_count + 1)) ;;
      esac
    done
    dependency_count=${#dependency_indices[@]}
    menu_screen
    screen_title 'Dependencies' 'Installed only because another selected package needs them. This list is not editable.'
    if ((dependency_count)); then
      show_dependency_table "${dependency_indices[@]}"
    else
      printf '  No package is installed only as a dependency.\n'
    fi
    if ((${#technical[@]})); then
      printf '\n%sAdditional locked requirements (pacman)%s\n' "$style_bold" "$style_reset"
      for entry in "${technical[@]}"; do printf '  [D] %s\n' "$entry"; done
    fi
    printf '\n%sPlan%s  required %d · recommended %d · optional %d · dependencies %d\n' \
      "$style_bold" "$style_reset" "$required_count" "$recommended_count" "$optional_count" "$dependency_count"
    printf '%s  pacman %d · AUR %d · Flatpak %d · %d catalog package(s)%s\n' \
      "$style_dim" "${#pacman_packages[@]}" "${#aur_packages[@]}" "${#flatpak_packages[@]}" \
      "$((required_count + recommended_count + optional_count + dependency_count))" "$style_reset"
    show_notices
    printf '\n%sThis is the final confirmation: the listed packages will be installed.%s\n' \
      "$style_dim" "$style_reset"
    printf '%sPress Enter to install, type back to change selections, or cancel to abort.%s\n' \
      "$style_dim" "$style_reset"
    read -r -p 'Confirm: ' answer || cancel
    trim "$answer"; answer=$REPLY
    case $answer in
      ''|install|yes|y) navigation=install; return ;;
      back) navigation=back; return ;;
      cancel|quit|q) cancel ;;
      help|\?)
        notice '%s' 'Dependencies are selected automatically and cannot be changed here.
Press Enter to install, back to edit Recommended or Optional, or cancel to abort.'
        ;;
      *) notice 'Press Enter to install, type back to change selections, or cancel to abort.' ;;
    esac
  done
}

declare -a pacman_packages=() aur_packages=() flatpak_packages=() technical=()
add_requirement() {
  local package=$1 existing
  for existing in "${pacman_packages[@]}"; do [[ $existing != "$package" ]] || return 0; done
  pacman_packages+=("$package")
}

build_plan() {
  local index
  pacman_packages=(); aur_packages=(); flatpak_packages=(); technical=()
  for index in "${!packages[@]}"; do
    [[ ${effective[index]} == 1 ]] || continue
    case ${sources[index]} in
      pacman) pacman_packages+=("${packages[index]}") ;;
      aur) aur_packages+=("${packages[index]}") ;;
      flatpak) flatpak_packages+=("${packages[index]}") ;;
    esac
  done
  if ((${#aur_packages[@]})); then
    add_requirement base-devel; add_requirement git
    technical+=('base-devel: AUR build tools' 'git: AUR source retrieval')
  fi
  if ((${#flatpak_packages[@]})); then
    add_requirement flatpak
    technical+=('flatpak: selected Flatpak applications')
  fi
}

if [[ $mode == update ]]; then
  set_required_only
  resolve_selection
  build_plan
  printf 'Update mode: required packages only.\n'
else
  step=required
  while true; do
    case $step in
      required)
        screen_required
        step=recommended
        ;;
      recommended)
        screen_choices recommended 'Recommended packages' 'Selected by default. Disable any package that is not needed by another.'
        case $navigation in
          back) step=required ;;
          *) step=optional ;;
        esac
        ;;
      optional)
        screen_choices optional 'Optional packages' 'Disabled by default. Enable only what you need.'
        case $navigation in
          back) step=recommended ;;
          *) step=dependencies ;;
        esac
        ;;
      dependencies)
        screen_dependencies
        case $navigation in
          back) step=optional ;;
          install) break ;;
        esac
        ;;
    esac
  done
fi

trap 'printf "\nInstallation interrupted; check transactions already completed.\n" >&2; exit 130' INT TERM
native_needed=false
for package in "${pacman_packages[@]}"; do
  if ! pacman -Q "$package" >/dev/null 2>&1; then native_needed=true; fi
done
if [[ $mode == install || $native_needed == true ]]; then
  sudo pacman -Syu --needed "${pacman_packages[@]}" \
    || die 'pacman failed. AUR and Flatpak stages will not run.'
else
  printf 'Required native packages already installed; system upgrade skipped.\n'
fi
if ((${#aur_packages[@]})); then
  command -v "$helper" >/dev/null || die "AUR helper not found after pacman installation: $helper."
  "$helper" -S --needed "${aur_packages[@]}" || die 'AUR stage failed. Flatpak stage will not run.'
fi
if ((${#flatpak_packages[@]})); then
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo \
    || die 'Could not configure Flathub for this user.'
  flatpak install --user flathub "${flatpak_packages[@]}" || die 'Flatpak stage failed.'
fi
# Removal targets come exclusively from pacman's orphan query, never from
# deselected catalog entries. Do not recursively expand the removal transaction.
declare -A protected=()
for package in "${pacman_packages[@]}" "${aur_packages[@]}"; do protected[$package]=1; done
while true; do
  # Validate database access separately: -Qdtq also returns 1 for an empty list.
  pacman -Qq >/dev/null || die 'Cannot read the installed package database.'
  orphan_output=$(pacman -Qdtq 2>&1) || {
    status=$?
    [[ $status == 1 && -z $orphan_output ]] || die 'Could not query orphan packages.'
  }
  orphans=()
  while IFS= read -r package; do
    [[ -n $package ]] || continue
    [[ ${protected[$package]+present} ]] || orphans+=("$package")
  done <<< "$orphan_output"
  ((${#orphans[@]})) || break
  printf 'Removing orphan dependencies only: %s\n' "${orphans[*]}"
  sudo pacman -R -- "${orphans[@]}" || die 'Orphan cleanup canceled or failed.'
done
printf '\nPackage installation complete. install.sh will now check required services for next boot.\n'
