#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
bash tests/session/run-qml.sh
bash tests/session/session.sh
