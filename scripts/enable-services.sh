#!/usr/bin/env bash
set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ $EUID -ne 0 ]] || die 'Run this script as a regular user, without sudo.'
for tool in pacman sudo systemctl; do
  command -v "$tool" >/dev/null || die "Required command not found: $tool."
done

# Explicit package-to-unit mapping: do not enable every unit shipped by a package.
# Portals, GVfs and thumbnail services are activated on demand by the session.
service_packages=(sddm)
service_units=(sddm.service)

printf '\n=== Enable required services for next boot ===\n'
for i in "${!service_packages[@]}"; do
  package=${service_packages[i]}
  unit=${service_units[i]}
  if ! pacman -Q "$package" >/dev/null 2>&1; then
    printf 'Skipped %s: package %s is not installed.\n' "$unit" "$package"
    continue
  fi
  load_state=$(systemctl show --property=LoadState --value "$unit") \
    || die "Cannot inspect $unit. Check that systemd is running."
  [[ $load_state != not-found && -n $load_state ]] || die "Installed package $package has no available unit $unit."
  if systemctl is-active --quiet "$unit"; then
    printf 'Skipped %s: already active; enablement left unchanged.\n' "$unit"
    continue
  fi
  unit_state=$(systemctl show --property=UnitFileState --value "$unit") \
    || die "Cannot inspect enablement of $unit."
  case $unit_state in
    enabled)
      printf 'Skipped %s: already enabled.\n' "$unit"
      continue
      ;;
    masked|masked-runtime)
      die "$unit is masked. Resolve the mask manually before retrying."
      ;;
  esac
  if [[ $load_state == masked ]]; then
    die "$unit is masked. Resolve the mask manually before retrying."
  fi
  [[ $load_state == loaded ]] || die "Cannot enable $unit: load state is $load_state."

  if [[ $unit == sddm.service ]]; then
    manager_state=$(systemctl show --property=LoadState --value display-manager.service) \
      || die 'Cannot inspect the configured display manager.'
    if [[ $manager_state != not-found ]]; then
      manager=$(systemctl show --property=Id --value display-manager.service) \
        || die 'Cannot identify the configured display manager.'
      [[ $manager == "$unit" ]] \
        || die "Another display manager is configured ($manager). Resolve it manually before enabling SDDM."
    fi
  fi

  sudo systemctl enable "$unit" || die "Could not enable $unit."
  printf 'Enabled %s for next boot.\n' "$unit"
done
printf 'Service checks complete. No services started or restarted.\n'
