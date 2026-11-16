#!/usr/bin/env bash
# Share the bounded user-service lifetime fixture with the launcher suite.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
exec bash tests/applauncher/run-live.sh --notifications
