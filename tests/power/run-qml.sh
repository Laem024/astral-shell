#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
if ! command -v qs >/dev/null; then printf 'SKIP: Quickshell runtime checks require qs.\n'; exit 0; fi
exec bash tests/quickshell/runtime.sh
