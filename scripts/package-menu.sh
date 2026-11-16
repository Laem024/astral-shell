#!/usr/bin/env bash

# Interactive presentation only; never clear package-manager transaction output.
declare -a notices=()

# Style is opt-out for terminals that cannot render ANSI escapes.
style_reset='' style_bold='' style_dim='' style_red='' style_green='' style_yellow='' style_blue='' style_magenta='' style_cyan=''
if [[ -t 1 && ${TERM:-} != dumb && -z ${NO_COLOR:-} ]]; then
  style_reset=$'\033[0m'
  style_bold=$'\033[1m'
  style_dim=$'\033[2m'
  style_red=$'\033[31m'
  style_green=$'\033[32m'
  style_yellow=$'\033[33m'
  style_blue=$'\033[34m'
  style_magenta=$'\033[35m'
  style_cyan=$'\033[36m'
fi

notice() {
  local message
  printf -v message "$@"
  notices+=("$message")
}
show_notices() {
  local message
  for message in "${notices[@]}"; do printf '\n%s\n' "$message"; done
  notices=()
}
menu_screen() {
  local size rows measured
  if [[ -t 1 && -n ${TERM:-} && ${TERM:-} != dumb ]]; then
    printf '\033[H\033[2J'
  else
    printf '\n---\n'
  fi
  menu_width=80
  measured=${COLUMNS:-80}
  if command -v stty >/dev/null && size=$(stty size 2>/dev/null); then
    read -r rows measured <<< "$size"
    if [[ ! $measured =~ ^[1-9][0-9]{0,3}$ ]]; then measured=${COLUMNS:-80}; fi
  fi
  if [[ $measured =~ ^[1-9][0-9]{0,3}$ ]]; then menu_width=$measured; fi
}

screen_title() {
  local title=$1 subtitle=${2:-}
  printf '\n%s%s%s%s\n' "$style_bold" "$style_cyan" "$title" "$style_reset"
  if [[ -n $subtitle ]]; then
    printf '  %s%s%s\n' "$style_dim" "$subtitle" "$style_reset"
  fi
}

# Wrap each cell independently, retaining a single package per table row.
table_row() {
  local -a values=("$@") lines=()
  local -A cells=()
  local column line height=1
  for column in "${!values[@]}"; do
    mapfile -t lines < <(printf '%s\n' "${values[column]}" | fold -s -w "${table_widths[column]}")
    for line in "${!lines[@]}"; do cells[$column,$line]=${lines[line]}; done
    ((${#lines[@]} <= height)) || height=${#lines[@]}
  done
  for ((line = 0; line < height; line++)); do
    for column in "${!values[@]}"; do
      ((column == 0)) || printf ' | '
      printf '%-*s' "${table_widths[column]}" "${cells[$column,$line]:-}"
    done
    printf '\n'
  done
}

package_mark() {
  local index=$1
  if [[ ${levels[index]} == required ]]; then REPLY=R
  elif [[ ${chosen[index]} == 1 ]]; then REPLY=x
  elif [[ ${locked[index]} == 1 ]]; then REPLY=D
  else REPLY=' '
  fi
}

# Required packages are informational: no selection column, no toggles.
show_required_table() {
  local index position=0 longest=7 package_width purpose_width
  local -a table_widths=(3) headers=(ID) values=()
  local source_column=false purpose_column=false separator='' header column
  for index in "$@"; do
    ((${#packages[index]} <= longest)) || longest=${#packages[index]}
  done
  ((menu_width >= 45)) && source_column=true
  ((menu_width >= 120)) && purpose_column=true
  # ID width plus the separator before the package column.
  local fixed=6
  [[ $source_column == true ]] && fixed=$((fixed + 10))
  package_width=$((menu_width - fixed))
  if [[ $purpose_column == true ]]; then
    ((package_width <= longest)) || package_width=$longest
    if ((package_width > menu_width - fixed - 23)); then
      package_width=$((menu_width - fixed - 23))
    fi
    purpose_width=$((menu_width - fixed - package_width - 3))
  fi
  ((package_width >= 1)) || package_width=1
  table_widths+=("$package_width"); headers+=(Package)
  if [[ $source_column == true ]]; then table_widths+=(7); headers+=(Source); fi
  if [[ $purpose_column == true ]]; then table_widths+=("$purpose_width"); headers+=(Purpose); fi
  header=$(table_row "${headers[@]}")
  printf '%s%s%s\n' "$style_bold" "$header" "$style_reset"
  for column in "${!table_widths[@]}"; do
    [[ -z $separator ]] || separator+='-+-'
    printf -v REPLY '%*s' "${table_widths[column]}" ''
    separator+=${REPLY// /-}
  done
  printf '%s%s%s\n' "$style_dim" "$separator" "$style_reset"
  for index in "$@"; do
    position=$((position + 1))
    values=("$position" "${packages[index]}")
    if [[ $source_column == true ]]; then values+=("${sources[index]}"); fi
    if [[ $purpose_column == true ]]; then values+=("${descriptions[index]}"); fi
    table_row "${values[@]}"
  done
}

# Recommended and optional screens share this layout. IDs are local to the
# screen so users can write 1 or 1,3,6 without knowing catalog positions.
show_choice_table() {
  local index position=0 longest=7 package_width purpose_width
  local -a table_widths=(3 3) headers=(ID Sel) values=()
  local source_column=false purpose_column=false separator='' header column
  for index in "$@"; do
    ((${#packages[index]} <= longest)) || longest=${#packages[index]}
  done
  ((menu_width >= 45)) && source_column=true
  ((menu_width >= 120)) && purpose_column=true
  # ID and Sel columns plus the two separators before Package.
  local fixed=12
  [[ $source_column == true ]] && fixed=$((fixed + 10))
  package_width=$((menu_width - fixed))
  if [[ $purpose_column == true ]]; then
    ((package_width <= longest)) || package_width=$longest
    if ((package_width > menu_width - fixed - 23)); then
      package_width=$((menu_width - fixed - 23))
    fi
    purpose_width=$((menu_width - fixed - package_width - 3))
  fi
  ((package_width >= 1)) || package_width=1
  table_widths+=("$package_width"); headers+=(Package)
  if [[ $source_column == true ]]; then table_widths+=(7); headers+=(Source); fi
  if [[ $purpose_column == true ]]; then table_widths+=("$purpose_width"); headers+=(Purpose); fi
  header=$(table_row "${headers[@]}")
  printf '%s%s%s\n' "$style_bold" "$header" "$style_reset"
  for column in "${!table_widths[@]}"; do
    [[ -z $separator ]] || separator+='-+-'
    printf -v REPLY '%*s' "${table_widths[column]}" ''
    separator+=${REPLY// /-}
  done
  printf '%s%s%s\n' "$style_dim" "$separator" "$style_reset"
  for index in "$@"; do
    position=$((position + 1))
    package_mark "$index"
    values=("$position" "[$REPLY]" "${packages[index]}")
    if [[ $source_column == true ]]; then values+=("${sources[index]}"); fi
    if [[ $purpose_column == true ]]; then values+=("${descriptions[index]}"); fi
    table_row "${values[@]}"
  done
}

# Dependency screen: read-only rows with the packages that require each entry.
show_dependency_table() {
  local index longest=7 package_width needed_width used_width max_package
  local -a table_widths=() headers=(Package) values=()
  local source_column=false separator='' header column
  for index in "$@"; do
    ((${#packages[index]} <= longest)) || longest=${#packages[index]}
  done
  [[ $menu_width -ge 50 ]] && source_column=true
  package_width=$longest
  max_package=$((menu_width / 3))
  ((max_package >= 10)) || max_package=10
  ((package_width <= max_package)) || package_width=$max_package
  ((package_width >= 7)) || package_width=7
  table_widths+=("$package_width")
  used_width=$((package_width + 3))
  if [[ $source_column == true ]]; then
    table_widths+=(7); headers+=(Source)
    used_width=$((used_width + 10))
  fi
  needed_width=$((menu_width - used_width))
  ((needed_width >= 10)) || needed_width=10
  table_widths+=("$needed_width"); headers+=('Needed by')
  header=$(table_row "${headers[@]}")
  printf '%s%s%s\n' "$style_bold" "$header" "$style_reset"
  for column in "${!table_widths[@]}"; do
    [[ -z $separator ]] || separator+='-+-'
    printf -v REPLY '%*s' "${table_widths[column]}" ''
    separator+=${REPLY// /-}
  done
  printf '%s%s%s\n' "$style_dim" "$separator" "$style_reset"
  for index in "$@"; do
    values=("${packages[index]}")
    if [[ $source_column == true ]]; then values+=("${sources[index]}"); fi
    values+=("${reasons[index]}")
    table_row "${values[@]}"
  done
}
