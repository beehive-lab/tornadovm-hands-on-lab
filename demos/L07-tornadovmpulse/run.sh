#!/usr/bin/env bash
# L07 · TornadoVMPulse: writes profile.json for the dashboard  ·  any backend
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
tvm --enableProfiler silent --dumpProfiler "$HERE/profile.json" -m $EX.VectorAddInt 1000000
echo "Wrote $HERE/profile.json; upload it in TornadoVMPulse."
