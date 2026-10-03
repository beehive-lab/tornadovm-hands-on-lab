# Shared by the run-jitllm.sh scripts: jitLLM from a source build as the demo workload.
# Source it; do not run it. Needs:
#   JITLLM_ROOT       a jitLLM clone, built as in demos/L08-jitllm (scripts/tornadovm-dev.sh)
#   JITLLM_MODEL_DIR  the directory holding $JITLLM_MODEL (default: the current directory)
#   JDK 21 selected   e.g. sdk use java 21.0.2-open
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env/versions.env"

note() { echo "-- $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[ -n "${JITLLM_ROOT:-}" ] && [ -x "$JITLLM_ROOT/jitllm" ] \
  || die "set JITLLM_ROOT to a jitLLM clone built as in demos/L08-jitllm"
MODEL="${JITLLM_MODEL_DIR:-$PWD}/$JITLLM_MODEL"
[ -f "$MODEL" ] || die "model not found: $MODEL
  set JITLLM_MODEL_DIR, or download it: curl -L -O $JITLLM_MODEL_URL"

JAVA_VERSION="$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.specification\.version = //p')"
[ "$JAVA_VERSION" = 21 ] \
  || die "the jitLLM source build runs on JDK 21, found ${JAVA_VERSION:-no java}: sdk use java 21.0.2-open"

# TORNADOVM_HOME and PATH of the TornadoVM develop build that jitLLM was built against.
DEV_ENV="$("$JITLLM_ROOT/scripts/tornadovm-dev.sh" env 2>/dev/null)" \
  || die "no TornadoVM develop build for jitLLM; prepare it as in demos/L08-jitllm"
eval "$DEV_ENV"

# The launcher takes no JVM flags, so they go through JDK_JAVA_OPTIONS. Bailout off, as in lib.sh.
export JDK_JAVA_OPTIONS="-Dtornado.recover.bailout=False ${JDK_JAVA_OPTIONS:-}"

# run_jitllm LOG ARGS...: one generation on the GPU. The console output (tens of MB with
# profiling or bytecodes on) goes to LOG; only the throughput line is shown.
run_jitllm() {
  local log=$1; shift
  note "jitLLM · $JITLLM_MODEL · TornadoVM ${TORNADOVM_HOME##*/} · console output in $log"
  "$JITLLM_ROOT/jitllm" --gpu --gpu-memory "$JITLLM_GPU_MEMORY" --model "$MODEL" "$@" > "$log" 2>&1 \
    || { tail -20 "$log" >&2; die "jitLLM failed, see $log"; }
  grep -m1 'achieved tok/s' "$log" || true
}
