# Shared by the run-jitllm.sh scripts: jitLLM from a source build as the demo workload.
# Source it; do not run it. Needs:
#   JITLLM_ROOT       a built jitLLM clone (demos/L06-jitllm)
#   JITLLM_MODEL_DIR  the directory holding $JITLLM_MODEL (default: the current directory)
# The jar decides the rest:
#   jitllm-*-jdk21.jar      built with scripts/tornadovm-dev.sh: JDK 21 and that TornadoVM develop build
#   jitllm-*-jdk22plus.jar  JDK 22 or newer, and the TornadoVM SDK already in TORNADOVM_HOME
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env/versions.env"

note() { echo "-- $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[ -n "${JITLLM_ROOT:-}" ] || die "set JITLLM_ROOT to a built jitLLM clone (demos/L06-jitllm)"
[ -x "$JITLLM_ROOT/jitllm" ] || die "JITLLM_ROOT=$JITLLM_ROOT has no jitllm launcher; is it a jitLLM clone?"
MODEL="${JITLLM_MODEL_DIR:-$PWD}/$JITLLM_MODEL"
[ -f "$MODEL" ] || die "model not found: $MODEL
  set JITLLM_MODEL_DIR, or download it: curl -L -O $JITLLM_MODEL_URL"

# The jar the launcher will pick: a SNAPSHOT jar first, else any jitllm jar; the last in sort order.
# Globs expand in sorted order; an unmatched glob stays literal, which the -e test skips.
JAR=
for f in "$JITLLM_ROOT"/target/jitllm-*-SNAPSHOT.jar; do [ -e "$f" ] && JAR=$f; done
if [ -z "$JAR" ]; then
  for f in "$JITLLM_ROOT"/target/jitllm-*.jar; do [ -e "$f" ] && JAR=$f; done
fi
[ -n "$JAR" ] || die "no jar in $JITLLM_ROOT/target; build jitLLM as in demos/L06-jitllm"

JAVA_VERSION="$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.specification\.version = //p')"
case "$JAR" in
  *-jdk21*.jar)
    [ "$JAVA_VERSION" = 21 ] \
      || die "${JAR##*/} needs JDK 21, found ${JAVA_VERSION:-no java}: sdk use java 21.0.2-open"
    # TORNADOVM_HOME and PATH of the TornadoVM develop build that jitLLM was built against.
    DEV_ENV="$("$JITLLM_ROOT/scripts/tornadovm-dev.sh" env 2>/dev/null)" \
      || die "${JAR##*/} needs the TornadoVM develop build; prepare it as in demos/L06-jitllm"
    eval "$DEV_ENV"
    ;;
  *)
    [ "${JAVA_VERSION:-0}" -ge 22 ] 2>/dev/null \
      || die "${JAR##*/} needs JDK 22 or newer, found ${JAVA_VERSION:-no java}: sdk use java $JAVA_SDK"
    [ -n "${TORNADOVM_HOME:-}" ] && [ -d "$TORNADOVM_HOME" ] \
      || die "${JAR##*/} runs on the TornadoVM SDK in TORNADOVM_HOME, which is not set; see the README quick start"
    ;;
esac

# The launcher takes no JVM flags, so they go through JDK_JAVA_OPTIONS. Bailout off, as in lib.sh.
export JDK_JAVA_OPTIONS="-Dtornado.recover.bailout=False ${JDK_JAVA_OPTIONS:-}"

# run_jitllm LOG ARGS...: one generation on the GPU. The console output (tens of MB with
# profiling or bytecodes on) goes to LOG; only the throughput line is shown.
# JITLLM_PREFIX, an array, goes in front of the launcher, e.g. (nsys profile -o out).
JITLLM_PREFIX=()
run_jitllm() {
  local log=$1; shift
  note "jitLLM ${JAR##*/} · $JITLLM_MODEL · TornadoVM $(basename "$(readlink -f "$TORNADOVM_HOME")") · console output in $log"
  # the ${a[@]+...} form keeps an empty array safe under set -u on bash 3.2 (macOS)
  ${JITLLM_PREFIX[@]+"${JITLLM_PREFIX[@]}"} "$JITLLM_ROOT/jitllm" --gpu --gpu-memory "$JITLLM_GPU_MEMORY" --model "$MODEL" "$@" > "$log" 2>&1 \
    || { tail -20 "$log" >&2; die "jitLLM failed, see $log"; }
  grep -m1 'achieved tok/s' "$log" || true
}
