#!/usr/bin/env bash
# L07 · starts the TornadoVMPulse dashboard; clones it and installs its requirements on first use
#   ./tornadovm-pulse.sh [streamlit options]    e.g. --server.port 8502
# Prints every command before it runs it. The clone lives next to this script, with its own .venv.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/streamlit.sh"

streamlit_app "$TORNADOVMPULSE_REPO" "$HERE/TornadoVMPulse" src/app.py \
  "upload $HERE/profile.json (run.sh) or profile-jitllm.json (run-jitllm.sh) in the browser" "$@"
