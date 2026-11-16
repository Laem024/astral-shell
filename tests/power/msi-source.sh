#!/usr/bin/env bash
# Optional: use the downloaded upstream tree; no root actions or network access.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
source=${1:?Pass the reviewed msi-ec source tree}
runtime=$(astral_test_scratch power)
trap 'rm -rf -- "$runtime"' EXIT
bash scripts/install-msi-ec.sh --stage "$source" "$runtime/valid"
rg -Fx 'MAKE[0]="make KERNELRELEASE=${kernelver}"' "$runtime/valid/dkms.conf"
rg -Fx 'PACKAGE_NAME="msi-ec"' "$runtime/valid/dkms.conf"
cp -r "$runtime/valid" "$runtime/changed"
# Restore the original config before changing just one reviewed source byte.
cp "$source/dkms.conf" "$runtime/changed/dkms.conf"
printf '\n/* changed */\n' >> "$runtime/changed/msi-ec.c"
if bash scripts/install-msi-ec.sh --stage "$runtime/changed" "$runtime/rejected" > "$runtime/log" 2>&1; then exit 1; fi
rg -q 'Source differs from reviewed revision' "$runtime/log"
printf 'MSI_SOURCE_PASS\n'
