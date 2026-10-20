#!/usr/bin/env bash
# L16 · a Quarkus application with a LangChain4j AI service that streams a summary, token by token,
# from jitLLM on the GPU (streaming-summarization). About 10 seconds once the model is downloaded.
#   demos/L16-jitllm-quarkus-langchain4j/run.sh
# Run setup.sh once first. Runs on its own SDK, $QUARKUS_TORNADOVM_SDK_*. Prints the command before it runs it.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

JAR="$JITLLM_QUARKUS_ROOT/demos/streaming-summarization/target/quarkus-app/quarkus-run.jar"
[ -f "$JAR" ] || { echo "ERROR: streaming-summarization is not built: run $HERE/setup.sh" >&2; exit 1; }

note "streaming-summarization · TornadoVM $SDK_ID · Llama 3.2 1B F16 downloads to ~/.langchain4j/models/ on the first run"
cd "$JITLLM_QUARKUS_ROOT"
# The SDK's tornado-argfile points at tornadovm/current; tornado-args.sh writes one for this SDK
CMD=(java "@$(scripts/tornado-args.sh)" --add-modules jdk.incubator.vector $JVM_FLAGS -jar "$JAR")
echo "\$ ${CMD[*]}"
# The demo catches a failed generation, logs it and exits 0, so the log decides
LOG="$(mktemp)"
"${CMD[@]}" 2>&1 | tee "$LOG"
if grep -q 'Error in JitLLM\|Exception' "$LOG"; then
  echo "ERROR: jitLLM failed; see $LOG" >&2
  exit 1
fi
rm -f "$LOG"
