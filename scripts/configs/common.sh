#!/usr/bin/env bash

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Callers set these explicitly; defaults keep standalone modules safe under
# set -u. no_backup skips snapshots without ever deleting destination-only files.
dry_run=${dry_run:-false}
no_backup=${no_backup:-false}

# realpath -ms normalizes spelling without resolving symbolic links.
# Inspect every component, including broken links, before accessing a tree.
check_components() {
  local remaining=${1#/} current='/' part
  while [[ -n $remaining ]]; do
    part=${remaining%%/*}
    if [[ $remaining == */* ]]; then remaining=${remaining#*/}; else remaining=''; fi
    [[ -n $part ]] || continue
    current=${current%/}/$part
    [[ ! -L $current ]] || die "Symbolic links are not supported: $current"
  done
}

check_directory() {
  local path=$1 parent=$1
  check_components "$path"
  [[ ! -e $path || -d $path ]] || die "Expected a directory: $path"
  while [[ ! -e $parent ]]; do parent=${parent%/*}; [[ -n $parent ]] || parent=/; done
  [[ -d $parent && -x $parent && ( $dry_run == true || -w $parent ) ]] || die "Directory is not writable/searchable: $parent"
}

# Install a public command in ~/.local/bin. The caller supplies the body
# without the shebang; an existing command with different contents is backed
# up before it is replaced.
install_public_command() {
  local name=$1 body=$2 command_dir=${3:-$HOME/.local/bin}
  local command_file=$command_dir/$name temporary
  check_directory "$command_dir"
  check_components "$command_file"
  if [[ -e $command_file ]]; then
    [[ -f $command_file && ( $dry_run == true || -w $command_file ) ]] || die "Cannot replace command: $command_file"
  fi
  if [[ $dry_run == true ]]; then
    if [[ $no_backup == true ]]; then
      printf 'Install command without backup if changed: %q\n' "$command_file"
    else
      printf 'Install command with backup if changed: %q\n' "$command_file"
    fi
    return
  fi
  mkdir -p -- "$command_dir"
  temporary=$(mktemp "$command_dir/.$name.XXXXXX")
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$body"; } > "$temporary"
  chmod 755 "$temporary"
  if [[ -f $command_file ]] && cmp -s -- "$temporary" "$command_file"; then
    rm -- "$temporary"
    return
  fi
  if [[ -f $command_file && $no_backup != true ]]; then
    cp -p -- "$command_file" "$command_file.backup-$(date -u +%Y%m%dT%H%M%S)-$$"
  fi
  mv -- "$temporary" "$command_file"
}

find_configs() {
  local path scan_ok=false found=false
  root_path=$(realpath -ms -- "$root_path")
  check_components "$root_path"
  [[ -d $root_path && -r $root_path && -x $root_path ]] || die "Cannot search directory: $root_path"
  printf 'Destination: %q\nCandidates under %q:\n' "$destination" "$root_path"
  while IFS= read -r -d '' path; do
    if [[ -z $path ]]; then scan_ok=true; break; fi
    if [[ ! -L $path ]] && module_candidate "$path"; then
      printf '  %q\n' "$path"
      found=true
    fi
  done < <(find -P "$root_path" \( -name .git -o -name .backups \) -prune -o -print0 && printf '\0')
  [[ $scan_ok == true ]] || die 'Search was incomplete; check directory permissions.'
  [[ $found == true ]] || printf '  No candidates found.\n'
}

apply_configs() {
  local path relative target parent scan_ok=false backup_root='' completed=0 changed=false
  local -a retired_files=() files=() relatives=() directories=() backup_files=() backup_directories=() changed_indices=() added_indices=() replaced_indices=()
  source_path=$(realpath -ms -- "$source_path")
  check_components "$source_path"
  check_components "$destination"
  [[ -d $source_path && -r $source_path && -x $source_path ]] || die "Source must be a readable directory: $source_path"
  [[ $source_path != / && $destination != / ]] || die 'The filesystem root cannot be a source or destination.'
  case ${source_path##*/} in .git|.backups) die 'Reserved source directory name.' ;; esac
  if [[ $source_path == "$destination" || $source_path == "$destination/"* || $destination == "$source_path/"* ]]; then
    die 'Source and destination must not overlap.'
  fi
  check_directory "$destination"
  # Only internal directory links are supported; materialize them on install.
  while IFS= read -r -d '' path; do
    target=$(realpath -e -- "$path") || die "Broken source link: $path"
    [[ -d $target && $target == "$source_path/"* ]] || die "Source link must point to an internal directory: $path"
  done < <(find -P "$source_path" -type l -print0)
  while IFS= read -r -d '' path; do
    if [[ -z $path ]]; then scan_ok=true; break; fi
    [[ $path != "$source_path" ]] || continue
    relative=${path#"$source_path/"}
    # Quickshell settings are installed by module_prepare_settings and are
    # never overwritten by a later apply; the user's copy is authoritative.
    if [[ $application == quickshell && ( $relative == settings.json || $relative == */settings.json ) ]]; then
      continue
    fi
    if [[ -d $path ]]; then
      [[ -r $path && -x $path ]] || die "Cannot read directory: $path"
      directories+=("$relative")
    elif [[ -f $path ]]; then
      files+=("$path"); relatives+=("$relative")
    else
      die "Unsupported source entry: $path"
    fi
  done < <(find -L "$source_path" \( -name .git -o -name .backups -o -name .gitkeep \) -prune -o -print0 && printf '\0')
  [[ $scan_ok == true ]] || die 'Source scan failed; nothing has been copied.'
  (( ${#files[@]} )) || die "No applicable files in $source_path. Add your configuration before applying."

  # Validate the entire copy plan before creating directories or backups.
  for relative in "${directories[@]}"; do check_directory "$destination/$relative"; done
  local i
  for i in "${!files[@]}"; do
    [[ -r ${files[i]} ]] || die "Cannot read source: ${files[i]}"
    target=$destination/${relatives[i]}
    check_components "$target"
    check_directory "${target%/*}"
    if [[ -e $target ]]; then
      [[ -f $target && -r $target && ( $dry_run == true || -w $target ) ]] || die "Cannot overwrite nonregular or inaccessible file: $target"
    fi
  done
  if declare -F module_retired_files >/dev/null; then module_retired_files; fi
  (( ${#retired_files[@]} == 0 )) || changed=true
  # Content and mode determine changes; timestamps alone do not trigger writes.
  for relative in "${directories[@]}"; do
    [[ -d $destination/$relative ]] || changed=true
  done
  for i in "${!files[@]}"; do
    target=$destination/${relatives[i]}
    if [[ ! -f $target ]] || ! cmp --silent -- "${files[i]}" "$target" \
      || [[ $(stat -c %a -- "${files[i]}") != "$(stat -c %a -- "$target")" ]]; then
      changed=true
      if [[ -e $target ]]; then replaced_indices+=("$i"); else added_indices+=("$i"); fi
    fi
  done
  # Publish new dependencies before replacing files that may import them.
  # Quickshell can reload as soon as an existing QML file changes; a missing
  # new component makes that reload fail and leaves the old UI running.
  changed_indices=("${added_indices[@]}" "${replaced_indices[@]}")
  if [[ $application == quickshell ]] && module_settings_missing; then changed=true; fi
  if [[ $changed == false ]]; then
    printf '%s: configuration already matches; no writes or backup needed.\n' "$application"
    return
  fi
  if [[ $no_backup == true ]]; then
    printf 'Backup disabled (--no-backup); destination-only files are retained.\n'
  else
    # Snapshot the whole existing tree, not just files that will be overwritten.
    # Prune only the destination's backup store to avoid recursively backing it up.
    if [[ -d $destination ]]; then
      check_directory "$destination/.backups"
      scan_ok=false
      while IFS= read -r -d '' path; do
        if [[ -z $path ]]; then scan_ok=true; break; fi
        [[ $path != . ]] || continue
        relative=${path#./}
        path=$destination/$relative
        [[ ! -L $path ]] || die "Configuration contains a symbolic link: $path"
        if [[ -d $path ]]; then
          [[ -r $path && -x $path ]] || die "Cannot back up directory: $path"
          backup_directories+=("$relative")
        elif [[ -f $path && -r $path ]]; then
          backup_files+=("$relative")
        else
          die "Cannot back up unsupported or unreadable entry: $path"
        fi
      done < <(cd -- "$destination" && find -P . -path './.backups' -prune -o -print0 && printf '\0')
      [[ $scan_ok == true ]] || die 'Configuration scan failed; nothing has been copied.'
    fi
  fi
  printf 'Source: %q\nDestination: %q\n' "$source_path" "$destination"
  if [[ $no_backup == true ]]; then
    printf 'No backup will be created; project files overwrite matching destination paths.\n'
  elif [[ -d $destination ]]; then
    printf 'Full backup: %q (%s files, %s directories; previous backups excluded)\n' \
      "$destination/.backups/<UTC-date>-<unique-id>/" "${#backup_files[@]}" "${#backup_directories[@]}"
  else
    printf 'New destination; no previous configuration to back up.\n'
  fi
  for relative in "${directories[@]}"; do printf 'Directory: %q\n' "$destination/$relative"; done
  for i in "${changed_indices[@]}"; do
    relative=${relatives[i]}
    target=$destination/$relative
    if [[ -e $target ]]; then
      if [[ $no_backup == true ]]; then
        printf 'Overwrite without backup: %q\n' "$target"
      else
        printf 'Overwrite after full backup: %q\n' "$target"
      fi
    else
      printf 'Create: %q\n' "$target"
    fi
  done
  for relative in "${retired_files[@]}"; do printf 'Retire unchanged project file: %q\n' "$destination/$relative"; done
  if [[ $dry_run == true ]]; then
    if [[ $application == quickshell ]]; then module_settings_plan; fi
    printf 'Dry run complete. No files or directories created.\n'
    return
  fi
  # Preserve partial backups/copies on failure; never remove configuration paths.
  if [[ $no_backup == true ]]; then
    trap 'printf "Apply failed after %s completed file copies. No backup was requested (--no-backup).\n" "${completed:-0}" >&2' EXIT
  else
    trap 'printf "Apply failed after %s completed file copies. Backup: %s\n" "${completed:-0}" "${backup_root:-none created}" >&2' EXIT
    if [[ -d $destination ]]; then
      mkdir -p -- "$destination/.backups"
      backup_root=$(mktemp -d -- "$destination/.backups/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
      for relative in "${backup_directories[@]}"; do mkdir -p -- "$backup_root/$relative"; done
      for relative in "${backup_files[@]}"; do
        parent=$backup_root/$relative
        mkdir -p -- "${parent%/*}"
        cp --preserve=mode,timestamps --no-dereference -- "$destination/$relative" "$backup_root/$relative"
        cmp --silent -- "$destination/$relative" "$backup_root/$relative"
      done
      printf 'Full backup complete and file contents verified: %q\n' "$backup_root"
    fi
  fi
  mkdir -p -- "$destination"
  for relative in "${directories[@]}"; do mkdir -p -- "$destination/$relative"; done
  if [[ $application == quickshell ]]; then module_prepare_settings; fi
  for i in "${changed_indices[@]}"; do
    target=$destination/${relatives[i]}
    cp --preserve=mode,timestamps --no-dereference -- "${files[i]}" "$target"
    completed=$((completed + 1))
  done
  for relative in "${retired_files[@]}"; do rm -- "$destination/$relative"; done
  trap - EXIT
  printf 'Applied %s files. Retired only unchanged legacy project files.\n' "$completed"
  if [[ $application == quickshell ]]; then
    printf 'To launch manually: qs --path %q\n' "$destination"
  fi
}
