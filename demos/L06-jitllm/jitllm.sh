#!/usr/bin/env bash
# L06 · runs the jitLLM that setup.sh built, on the GPU, with its JDK, TornadoVM build and model
#   ./jitllm.sh          one generation of the example prompt
#   ./jitllm.sh serve    the OpenAI-compatible server on port 8090 (L10)
# Adds --gpu, --gpu-memory $JITLLM_GPU_MEMORY and the model.
# Prints the command before it runs it.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/jitllm.sh"
note "jitLLM ${JAR##*/} · $JITLLM_MODEL · TornadoVM $(basename "$(readlink -f "$TORNADOVM_HOME")") · JDK $(java_version "$JAVA_HOME")"

cd "$JITLLM_ROOT"
if [ "${1:-}" = serve ]; then
  shift
  # Stop jitLLM servers left from earlier runs: they hold port 8090 and GPU memory. Only jitLLM's
  # server class matches; anything else listening on the port is left alone.
  SERVER=org.beehive.jitllm.server.OpenAIServer
  if pgrep -f "$SERVER" >/dev/null; then
    note "stopping the jitLLM server from an earlier run: $(pgrep -f "$SERVER" | tr '\n' ' ')"
    pkill -f "$SERVER" || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$SERVER" >/dev/null || break; sleep 1; done
    pkill -9 -f "$SERVER" || true
  fi
  set -- serve --port 8090 -m "$MODEL" --gpu --gpu-memory "$JITLLM_GPU_MEMORY" "$@"
else
  set -- --gpu --gpu-memory "$JITLLM_GPU_MEMORY" --model "$MODEL" --prompt "Explain GPU acceleration in one sentence."
fi
echo "\$ ./jitllm $*"
exec ./jitllm "$@"
