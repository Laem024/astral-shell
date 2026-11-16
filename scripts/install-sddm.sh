#!/usr/bin/env bash
# Install or update the Astral SDDM theme without touching other themes.
set -euo pipefail

base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$base/scripts/configs/common.sh"

usage() {
  cat <<'EOF'
Usage:
  install-sddm.sh [install|update]
  install-sddm.sh --stage ABSOLUTE_DIR [install|update]
  install-sddm.sh --system [install|update]

install creates or refreshes /usr/share/sddm/themes/astral.
update installs it when missing and refreshes it when present.
Only the Astral theme is touched; other SDDM themes are never modified.
No backups are created. An existing theme.conf is preserved so local
customizations survive updates. --stage writes under a temporary root and
is intended for tests.
EOF
}

case ${1:-install} in
  install|update)
    [[ $# -le 1 && $EUID != 0 ]] || { usage >&2; exit 2; }
    command -v sudo >/dev/null 2>&1 || die 'Required command not found: sudo.'
    exec sudo bash "$base/scripts/install-sddm.sh" --system "${1:-install}"
    ;;
  --system)
    [[ $# -le 2 && $EUID == 0 ]] || { usage >&2; exit 2; }
    mode=${2:-install}
    stage_root=''
    ;;
  --stage)
    [[ $# -ge 2 && $# -le 3 ]] || { usage >&2; exit 2; }
    stage_root=$2
    mode=${3:-install}
    [[ $stage_root == /* && $stage_root != / ]] || die '--stage requires an absolute directory other than /.'
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case $mode in
  install|update) ;;
  *) usage >&2; exit 2 ;;
esac

for tool in find install cmp stat realpath sudo; do
  if [[ $tool == sudo && $stage_root != '' ]]; then
    continue
  fi
  command -v "$tool" >/dev/null 2>&1 || die "Required command not found: $tool."
done

source_theme=$base/config/sddm/astral
source_dropin=$base/config/sddm/zz-astral-theme.conf
source_helper=$base/scripts/sddm-background.sh

theme_dir=$stage_root/usr/share/sddm/themes
config_dir=$stage_root/etc/sddm.conf.d
helper_dir=$stage_root/usr/local/bin
legacy_conf=$stage_root/etc/sddm.conf
target_theme=$theme_dir/astral
target_dropin=$config_dir/zz-astral-theme.conf
target_helper=$helper_dir/astral-sddm-background

check_components "$source_theme"
check_components "$source_dropin"
check_components "$source_helper"
[[ -d $source_theme && -r $source_theme && -x $source_theme ]] || die "Source theme is missing: $source_theme"
[[ -f $source_dropin && -r $source_dropin ]] || die "Source SDDM configuration is missing: $source_dropin"
[[ -f $source_helper && -r $source_helper ]] || die "Source helper is missing: $source_helper"
for required in Main.qml metadata.desktop theme.conf .astral-theme; do
  [[ -f $source_theme/$required ]] || die "Theme source requires: $source_theme/$required"
done
if find -P "$source_theme" -type l -print -quit | grep -q .; then
  die "Theme source contains a symbolic link: $source_theme"
fi
if find -P "$source_theme" ! -type d ! -type f -print -quit | grep -q .; then
  die "Theme source contains an unsupported entry: $source_theme"
fi

source_theme=$(realpath -ms -- "$source_theme")
source_dropin=$(realpath -ms -- "$source_dropin")
source_helper=$(realpath -ms -- "$source_helper")
theme_dir=$(realpath -ms -- "$theme_dir")
config_dir=$(realpath -ms -- "$config_dir")
helper_dir=$(realpath -ms -- "$helper_dir")
target_theme=$(realpath -ms -- "$target_theme")
target_dropin=$(realpath -ms -- "$target_dropin")
target_helper=$(realpath -ms -- "$target_helper")

check_components "$theme_dir"
check_components "$config_dir"
check_components "$helper_dir"
check_components "$target_theme"
check_components "$target_dropin"
check_components "$target_helper"
check_directory "$theme_dir"
check_directory "$config_dir"
check_directory "$helper_dir"

theme_exists=false
if [[ -e $target_theme || -L $target_theme ]]; then
  [[ -d $target_theme && ! -L $target_theme ]] || die "Expected a directory: $target_theme"
  theme_exists=true
  if [[ ! -f $target_theme/.astral-theme ]] \
    && ! { [[ -f $target_theme/metadata.desktop ]] && grep -qx 'Theme-Id=astral' "$target_theme/metadata.desktop"; }; then
    if [[ -n $(find -P "$target_theme" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
      die "Refusing to replace an existing non-Astral theme: $target_theme"
    fi
  fi
fi

printf 'Astral SDDM theme: %s\n' "$target_theme"
printf 'Theme selection: %s\n' "$target_dropin"
printf 'Background helper: %s\n' "$target_helper"
printf 'Mode: %s\n' "$mode"

# Preserve local theme.conf customizations. QML defaults cover new keys.
theme_conf_preserved=false
if [[ $theme_exists == true && -f $target_theme/theme.conf && ! -L $target_theme/theme.conf ]]; then
  theme_conf_preserved=true
fi

install -d -m755 -- "$theme_dir" "$config_dir" "$helper_dir"

updated=0
unchanged=0
while IFS= read -r -d '' directory; do
  [[ $directory == "$source_theme" ]] && continue
  relative=${directory#"$source_theme"/}
  [[ -n $relative ]] || continue
  install -d -m755 -- "$target_theme/$relative"
done < <(find -P "$source_theme" -type d -print0)

while IFS= read -r -d '' file; do
  relative=${file#"$source_theme"/}
  destination=$target_theme/$relative
  check_components "$destination"

  if [[ $relative == theme.conf && $theme_conf_preserved == true ]]; then
    continue
  fi

  if [[ -e $destination || -L $destination ]]; then
    [[ -f $destination && ! -L $destination ]] || die "Expected a regular file: $destination"
    if cmp --silent -- "$file" "$destination" \
      && [[ $(stat -c %a -- "$destination") == 644 ]]; then
      unchanged=$((unchanged + 1))
      continue
    fi
  fi

  install -Dm644 -- "$file" "$destination"
  updated=$((updated + 1))
done < <(find -P "$source_theme" -type f -print0)

# The drop-in is owned by this installer. It is the only SDDM configuration
# file written; other configuration files and other themes are untouched.
if [[ -e $target_dropin || -L $target_dropin ]]; then
  [[ -f $target_dropin && ! -L $target_dropin ]] || die "Expected a regular file: $target_dropin"
fi
if [[ ! -f $target_dropin ]] || ! cmp --silent -- "$source_dropin" "$target_dropin"; then
  install -Dm644 -- "$source_dropin" "$target_dropin"
  updated=$((updated + 1))
else
  unchanged=$((unchanged + 1))
fi

if [[ -e $target_helper || -L $target_helper ]]; then
  [[ -f $target_helper && ! -L $target_helper ]] || die "Expected a regular file: $target_helper"
  grep -qx '# astral-sddm-background' "$target_helper" \
    || die "Refusing to replace a foreign command: $target_helper"
fi
if [[ ! -f $target_helper ]] || ! cmp --silent -- "$source_helper" "$target_helper" \
  || [[ $(stat -c %a -- "$target_helper") != 755 ]]; then
  install -Dm755 -- "$source_helper" "$target_helper"
  updated=$((updated + 1))
else
  unchanged=$((unchanged + 1))
fi

if [[ $theme_conf_preserved == true ]]; then
  printf 'Preserved existing theme.conf (customizations kept).\n'
fi
printf 'Updated %s file(s); %s already matched.\n' "$updated" "$unchanged"

if [[ -f $legacy_conf ]] && grep -qE '^[[:space:]]*Current[[:space:]]*=' "$legacy_conf"; then
  printf 'Warning: %s sets Theme Current and overrides %s.\n' "$legacy_conf" "$target_dropin" >&2
fi

printf 'The theme will be used the next time SDDM starts; the current session was not touched.\n'
