#!/usr/bin/env bash
# L08 · starts the TornadoViz visualizer; clones it and installs its requirements on first use
#   ./tornadoviz.sh [streamlit options]    e.g. --server.port 8502
# Prints every command before it runs it. The clone lives next to this script, with its own .venv.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/streamlit.sh"

streamlit_app "$TORNADOVIZ_REPO" "$HERE/TornadoViz" tornado-visualizer-fixed.py \
  "load a log from $HERE/bytecodes (run.sh) or bytecodes-jitllm (run-jitllm.sh) in the browser" "$@"
