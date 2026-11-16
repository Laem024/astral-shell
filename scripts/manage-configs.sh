#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# Modules are trusted repository code, never configuration supplied by the user.
source "$SCRIPT_DIR/configs/common.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/manage-configs.sh find <application> --root <path> [--name <name>]
  bash scripts/manage-configs.sh apply <application|all> [--module <module>] [--source <path>] [--name <name>] [--dry-run] [--no-backup]

Applications: hyprland, quickshell, monitor, fish, gtk-3.0,
gtk-4.0, kitty, qt5ct, qt6ct, xdg-desktop-portal, xfce4. apply all skips
missing/empty sources.

Apply copies config/<application>/ from this project's root into the destination.
The monitor application installs config/monitor/ and the astral-monitor command.
--name selects a Quickshell subdirectory; the default is the Quickshell root.
--module installs one Quickshell module and the shared root dependencies.
--source replaces that module with a directory containing shell.qml or a QML
file. External modules do not need settings.json or session.sh.
Public commands: astral-shell, astral-bar, astral-launcher, astral-wallpaper,
astral-polkit, astral-lock, astral-session, astral-clipboard, astral-overview and astral-shortcuts.
--name selects a configuration destination. Settings are preserved and common
preferences are separated from bar preferences after backing up the destination.
--no-backup explicitly skips backups. Destination-only files are retained.
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
(( $# >= 2 )) || { usage >&2; exit 1; }
action=$1
application=$2
shift 2
case $action in find|apply) ;; *) die "Unknown command: $action" ;; esac
if [[ $application == all ]]; then
  [[ $action == apply ]] || die 'all is only supported with apply.'
  for option in "$@"; do
    case $option in
      --dry-run|--no-backup) ;;
      *) die 'apply all accepts only --dry-run and --no-backup.' ;;
    esac
  done
  for app in hyprland quickshell monitor fish gtk-3.0 gtk-4.0 kitty qt5ct qt6ct xdg-desktop-portal xfce4; do
    source_path=$PROJECT_ROOT/config/$app
    check_components "$source_path"
    if [[ ! -e $source_path ]]; then
      printf 'Skipped %s: source missing.\n' "$app"
      continue
    fi
    [[ -d $source_path ]] || die "Expected source directory: $source_path"
    entries=$(find -P "$source_path" \( -name .git -o -name .backups -o -name .gitkeep \) -prune -o ! -type d -print) \
      || die "Cannot scan source: $source_path"
    if [[ -z $entries ]]; then
      printf 'Skipped %s: no applicable source files.\n' "$app"
      continue
    fi
    bash "$SCRIPT_DIR/manage-configs.sh" apply "$app" "$@"
  done
  exit 0
fi
case $application in
  hyprland|quickshell|monitor|fish|gtk-3.0|gtk-4.0|kitty|qt5ct|qt6ct|xdg-desktop-portal|xfce4) source "$SCRIPT_DIR/configs/$application.sh" ;;
  *) die "Unsupported application: $application" ;;
esac

root_path=''
source_path=$PROJECT_ROOT/config/$application
config_name=''
selected_module=''
module_source=''
dry_run=false
no_backup=false
declare -A seen_options=()
while (( $# )); do
  option=$1
  case $option in
    --root|--name|--module|--source|--dry-run|--no-backup) ;;
    *) die "Unknown option: $option" ;;
  esac
  [[ ! ${seen_options[$option]+present} ]] || die "Repeated option: $option"
  seen_options[$option]=1
  case $option in
    --root|--name|--module|--source)
      (( $# >= 2 )) && [[ -n $2 && $2 != --* ]] || die "Missing value for $option"
      case $option in
        --root) root_path=$2 ;;
        --name) config_name=$2 ;;
        --module) selected_module=$2 ;;
        --source) module_source=$2 ;;
      esac
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    --no-backup) no_backup=true; shift ;;
  esac
done
if [[ $no_backup == true && $action != apply ]]; then
  die '--no-backup is only supported with apply.'
fi
if [[ ${seen_options[--module]+present} || ${seen_options[--source]+present} ]]; then
  [[ $application == quickshell ]] || die '--module and --source are only supported for Quickshell.'
  [[ $action == apply ]] || die '--module and --source are only supported with apply.'
fi
if [[ ${seen_options[--module]+present} ]]; then
  [[ $selected_module =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ && $selected_module != .backups ]] || die 'Use a single module identifier.'
  [[ $selected_module != common && $selected_module != shell.qml && $selected_module != settings.json && $selected_module != dispatch.sh ]] || die 'Reserved root component name.'
  [[ " ${module_names[*]} " == *" $selected_module "* || -n $module_source ]] || die 'Pending modules require an external --source.'
fi
if [[ ${seen_options[--source]+present} ]]; then
  [[ ${seen_options[--module]+present} ]] || die '--source requires --module.'
fi
if [[ ${seen_options[--name]+present} ]]; then
  [[ $application == quickshell ]] || die '--name is only supported for Quickshell.'
  [[ $config_name =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ && $config_name != .backups && $config_name != .git ]] \
    || die 'Use a single configuration name containing letters, digits, underscores, dots or hyphens.'
fi
for tool in realpath find cp cmp mkdir mktemp date stat; do
  command -v "$tool" >/dev/null || die "Required command not found: $tool"
done
config_home=${XDG_CONFIG_HOME:-${HOME:?HOME must be set}/.config}
[[ $config_home == /* ]] || die 'XDG_CONFIG_HOME must be an absolute path.'
destination=$(realpath -ms -- "$(module_destination "$config_home" "$config_name")")

# Module selection narrows both the source and the destination; commands still
# embed the Quickshell root so every installed command stays in one place.
quickshell_destination=$destination
module_root=$quickshell_destination
if [[ -n $selected_module ]]; then
  # Stage root dependencies once so the common copier backs up the full tree,
  # including preferences, for both complete and partial installations.
  selected_source=${module_source:-$PROJECT_ROOT/config/quickshell/$selected_module}
  selected_source=$(realpath -ms -- "$selected_source")
  check_components "$selected_source"
  [[ -r $selected_source ]] || die "Unreadable module: $selected_source"
  if [[ -d $selected_source ]]; then
    [[ -f $selected_source/shell.qml ]] || die 'Custom module requires shell.qml.'
  else
    [[ -f $selected_source && $selected_source == *.qml ]] || die 'Expected a QML file or module directory.'
  fi
  staging_root=${XDG_CACHE_HOME:-$HOME/.cache}/astral-shell/install
  [[ $staging_root == /* ]] || die 'XDG_CACHE_HOME must be absolute.'
  mkdir -p -m 700 -- "$staging_root"
  staging=$(mktemp -d "$staging_root/staging-XXXXXXXX")
  trap 'rm -rf -- "$staging"' EXIT
  cp -a -- "$PROJECT_ROOT/config/quickshell/common" "$staging/common"
  for root_file in shell.qml bar.qml recorder.qml launcher.qml launcher-control.qml wallpaper.qml wallpaper-control.qml polkit.qml polkit-control.qml lock.qml lock-control.qml idle.qml session.qml session-control.qml clipboard.qml clipboard-control.qml overview.qml overview-control.qml shortcuts.qml shortcuts-control.qml settings.json dispatch.sh; do cp -- "$PROJECT_ROOT/config/quickshell/$root_file" "$staging/$root_file"; done
  if [[ -d $selected_source ]]; then cp -a -- "$selected_source" "$staging/$selected_module"
  else mkdir -- "$staging/$selected_module"; cp -- "$selected_source" "$staging/$selected_module/shell.qml"; fi
  source_path=$staging
fi

case $action in
  find)
    [[ -n $root_path && $dry_run == false ]] \
      || die 'find requires --root and does not accept --dry-run.'
    find_configs
    ;;
  apply)
    [[ -z $root_path ]] || die 'apply does not accept --root; it uses config/<application>/ in the project.'
    [[ $EUID -ne 0 ]] || die 'Apply configurations as a regular user, without sudo.'
    apply_configs
    if declare -F module_install_command >/dev/null; then module_install_command; fi
    if [[ -n ${staging:-} ]]; then rm -rf -- "$staging"; fi
    ;;
esac
