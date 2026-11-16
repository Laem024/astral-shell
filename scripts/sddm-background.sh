#!/usr/bin/env bash
# astral-sddm-background
set -euo pipefail
trap 'exit 130' INT
trap 'exit 143' TERM

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

theme_dir=${ASTRAL_SDDM_THEME_DIR:-/usr/share/sddm/themes/astral}
theme_conf=$theme_dir/theme.conf
presets=(aurora nebula dusk void)

usage() {
  cat <<'EOF'
Usage:
  astral-sddm-background --list
  astral-sddm-background aurora|nebula|dusk|void
  astral-sddm-background /path/to/background.jpg

The image is copied into the Astral theme only. Other SDDM themes are never
modified and no backups are created. The change appears the next time SDDM
starts; the current session is not touched.
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if [[ ! -d $theme_dir || ! -f $theme_conf ]]; then
  die "Astral SDDM theme is not installed at $theme_dir."
fi
if [[ -L $theme_conf ]]; then
  die "Refusing to edit a symbolic link: $theme_conf"
fi

if [[ ${1:-} == --list ]]; then
  current=$(sed -n 's/^[[:space:]]*background[[:space:]]*=[[:space:]]*//p' "$theme_conf" | head -n 1)
  printf 'Presets: %s\n' "${presets[*]}"
  printf 'Current: %s\n' "${current:-none}"
  exit 0
fi

if [[ $# != 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $EUID != 0 && ! -w $theme_conf ]]; then
  command -v sudo >/dev/null 2>&1 || die 'sudo is required to edit the system theme.'
  script=$(realpath -- "$0")
  exec sudo -- "$script" "$@"
fi

value=''
argument=$1

if [[ -f $argument ]]; then
  [[ -r $argument ]] || die "Cannot read image: $argument"
  extension=${argument##*.}
  extension=${extension,,}
  case $extension in
    jpg|jpeg|png|webp) ;;
    *) die 'Use a JPG, PNG or WebP image.' ;;
  esac

  install -d -m755 -- "$theme_dir/assets/backgrounds"
  target=$theme_dir/assets/backgrounds/custom.$extension
  if [[ $(realpath -ms -- "$argument") != $(realpath -ms -- "$target") ]]; then
    install -m644 -- "$argument" "$target"
  fi
  value=assets/backgrounds/custom.$extension
else
  for preset in "${presets[@]}"; do
    if [[ $argument == "$preset" ]]; then
      value=$argument
      break
    fi
  done
  [[ -n $value ]] || die "Unknown preset or file: $argument"
fi

temporary=$(mktemp "$theme_dir/.theme.conf-XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT
awk -v value="$value" '
  /^[[:space:]]*background[[:space:]]*=/ { print "background=" value; done = 1; next }
  { print }
  END { if (!done) print "background=" value }
' "$theme_conf" > "$temporary"
install -m644 -- "$temporary" "$theme_conf"
printf 'Background set to %s\n' "$value"
printf 'It will appear the next time SDDM starts.\n'
