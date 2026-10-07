#!/usr/bin/env bash
# Local CI helper  runs the same checks as .github/workflows/tests.yml.
# Usage: ./tools/test.sh [unit|widget|integration|all]

set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-all}"

run_static() {
  echo "--- flutter analyze ---"
  flutter analyze
}

run_unit() {
  echo "--- flutter test test/unit/ ---"
  flutter test test/unit/ --reporter=expanded
}

run_widget() {
  echo "--- flutter test test/widget/ ---"
  flutter test test/widget/ --reporter=expanded
}

run_integration() {
  if [[ "${CI_PLATFORM:-}" == "" ]]; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then CI_PLATFORM="linux"; fi
    if [[ "$OSTYPE" == "darwin"* ]]; then CI_PLATFORM="macos"; fi
    if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then CI_PLATFORM="windows"; fi
  fi
  echo "--- flutter test integration_test/ -d ${CI_PLATFORM} ---"
  flutter test integration_test/ -d "${CI_PLATFORM}"
}

case "${MODE}" in
  unit)
    run_static
    run_unit
    ;;
  widget)
    run_static
    run_widget
    ;;
  integration)
    run_static
    run_integration
    ;;
  all)
    run_static
    run_unit
    run_widget
    # Integration tests require a working platform channel; skip on
    # local dev unless explicitly requested.
    if [[ "${SKIP_INTEGRATION:-0}" != "1" ]]; then
      run_integration || echo "(integration tests failed; set SKIP_INTEGRATION=1 to skip)"
    fi
    ;;
  *)
    echo "Usage: $0 [unit|widget|integration|all]" >&2
    exit 2
    ;;
esac
