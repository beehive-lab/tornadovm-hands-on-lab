#!/usr/bin/env bash
# L05 · TornadoViz: writes the bytecode log for the visualizer  ·  any backend
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
tvm --dumpBC "$HERE/bytecodes" -m $EX.VectorAddInt 1000000
echo "Wrote $HERE/bytecodes; load it in TornadoViz."
