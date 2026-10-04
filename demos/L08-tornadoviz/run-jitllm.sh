#!/usr/bin/env bash
# L08 · TornadoViz with jitLLM as the workload: writes the bytecode log to bytecodes-jitllm/  ·  any backend
#   ./run-jitllm.sh [max-new-tokens]    default 10; the log grows with every token
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/jitllm.sh"
OUT="$HERE/bytecodes-jitllm"

rm -rf "$OUT"
export JDK_JAVA_OPTIONS="-Dtornado.dump.bytecodes.dir=$OUT $JDK_JAVA_OPTIONS"
run_jitllm "$HERE/jitllm.log" --prompt "Hi" --max-new-tokens "${1:-10}" --print-bytecodes
echo "Wrote $OUT; load it in TornadoViz."
