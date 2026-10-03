#!/usr/bin/env bash
# L04 · TornadoVMPulse with jitLLM as the workload: writes profile-jitllm.json  ·  any backend
#   ./run-jitllm.sh [max-new-tokens]    default 30; the profile grows with every token
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/jitllm.sh"
OUT="$HERE/profile-jitllm.json"

rm -f "$OUT"
run_jitllm "$HERE/jitllm.log" --prompt "Explain GPU acceleration in one sentence." \
  --max-new-tokens "${1:-30}" --profiler --profiler-dump-file "$OUT"
echo "Wrote $OUT; upload it in TornadoVMPulse."
