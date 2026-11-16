#!/usr/bin/env bash
# Legacy test entry now exercises the shared QML panel controllers.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
exec bash tests/panels/control.sh "$@"
