#!/usr/bin/env bash
# Build umbrella dependencies first. Requires Python 3 and PyYAML.
# For a byte-for-byte comparison across all repository values fixtures:
#   git archive <base-sha> | tar -x -C <baseline-dir>
#   helm dependency build <baseline-dir>/charts/modulariot
#   charts/modulariot/tests/render-symptoms-engine.sh --baseline <baseline-dir>
set -euo pipefail
exec python3 "$(dirname "$0")/render-symptoms-engine.py" "$@"
