#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
for file in scripts/manage-configs.sh scripts/configs/quickshell.sh scripts/test-quickshell.sh scripts/install-power.sh config/quickshell/dispatch.sh tests/quickshell/*.sh; do bash -n "$file"; done
if rg -n '"(sh|bash)"|session\.sh' config/quickshell -g '*.qml' -g '*.js'; then
  printf 'Unexpected legacy runtime dependency.\n' >&2; exit 1
fi
bash tests/quickshell/install.sh
runner=/usr/lib/qt6/bin/qmltestrunner
if [[ -x $runner ]]; then
  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$runner" -input tests/quickshell
else printf 'SKIP: Qt QML test runner unavailable.\n'; fi
# Syntax parsing remains useful without the Quickshell type plugins.
if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
  source tests/xdg-scratch.sh
  lint_dir=$(astral_test_scratch qml-lint)
  log=$lint_dir/output
  trap 'rm -rf -- "$lint_dir"' EXIT
  mapfile -d '' qml_files < <(find config/quickshell -name '*.qml' -print0)
  /usr/lib/qt6/bin/qmllint --only-explicit-categories "${qml_files[@]}" > "$log" 2>&1 || { cat "$log"; exit 1; }

fi
if command -v qs >/dev/null; then
  bash tests/panels/central.sh
  bash tests/panels/startup.sh
  bash tests/panels/control.sh
  bash tests/quickshell/startup.sh
  bash tests/quickshell/runtime.sh
else printf 'SKIP: Quickshell runtime, compositor and hardware checks require CachyOS with qs.\n'; fi
printf 'QUICKSHELL_PASS\n'
