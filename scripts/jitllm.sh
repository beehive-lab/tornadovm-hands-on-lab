# Shared by the jitLLM scripts (L06 jitllm.sh, run-jitllm.sh, run-nsys.sh). Source it; do not run it.
# Defaults to the layout demos/L06-jitllm/setup.sh creates; override for another clone or model folder:
#   JITLLM_ROOT       a built jitLLM clone            (default: demos/L06-jitllm/jitllm)
#   JITLLM_MODEL_DIR  the folder holding $JITLLM_MODEL (default: JITLLM_ROOT)
# The jar decides the rest:
#   jitllm-*-jdk21.jar      built with scripts/tornadovm-dev.sh: JDK 21 and that TornadoVM develop build
#   jitllm-*-jdk22plus.jar  JDK 22 or newer, and the TornadoVM SDK already in TORNADOVM_HOME
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env/versions.env"

note() { echo "-- $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# The launcher reads JITLLM_ROOT and JAVA_HOME from the environment.
export JITLLM_ROOT="${JITLLM_ROOT:-$ROOT/demos/L06-jitllm/jitllm}"
[ -x "$JITLLM_ROOT/jitllm" ] \
  || die "no jitLLM clone at $JITLLM_ROOT: run demos/L06-jitllm/setup.sh, or set JITLLM_ROOT to your clone"
MODEL="${JITLLM_MODEL_DIR:-$JITLLM_ROOT}/$JITLLM_MODEL"
[ -f "$MODEL" ] || die "model not found: $MODEL
  run demos/L06-jitllm/setup.sh, or set JITLLM_MODEL_DIR to the folder that holds it"

# The jar the launcher will pick: a SNAPSHOT jar first, else any jitllm jar; the last in sort order.
# Globs expand in sorted order; an unmatched glob stays literal, which the -e test skips.
JAR=
for f in "$JITLLM_ROOT"/target/jitllm-*-SNAPSHOT.jar; do [ -e "$f" ] && JAR=$f; done
if [ -z "$JAR" ]; then
  for f in "$JITLLM_ROOT"/target/jitllm-*.jar; do [ -e "$f" ] && JAR=$f; done
fi
[ -n "$JAR" ] || die "no jar in $JITLLM_ROOT/target: run demos/L06-jitllm/setup.sh"

java_version() { "$1/bin/java" -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.specification\.version = //p'; }
JAVA_VERSION=
[ -z "${JAVA_HOME:-}" ] || JAVA_VERSION="$(java_version "$JAVA_HOME")"
case "$JAR" in
  *-jdk21*.jar)
    # Switch to SDKMAN!'s JDK 21 for this run only, so the shell can stay on the lab's JDK.
    if [ "$JAVA_VERSION" != 21 ]; then
      JDK21="${SDKMAN_DIR:-$HOME/.sdkman}/candidates/java/$JITLLM_JAVA_SDK"
      [ -x "$JDK21/bin/java" ] \
        || die "${JAR##*/} needs JDK 21, found ${JAVA_VERSION:-no JAVA_HOME}: sdk install java $JITLLM_JAVA_SDK"
      export JAVA_HOME="$JDK21" PATH="$JDK21/bin:$PATH"
    fi
    # TORNADOVM_HOME and PATH of the TornadoVM develop build that jitLLM was built against.
    DEV_ENV="$("$JITLLM_ROOT/scripts/tornadovm-dev.sh" env 2>/dev/null)" \
      || die "${JAR##*/} needs the TornadoVM develop build: run demos/L06-jitllm/setup.sh"
    eval "$DEV_ENV"
    ;;
  *)
    [ "${JAVA_VERSION:-0}" -ge 22 ] 2>/dev/null \
      || die "${JAR##*/} needs JDK 22 or newer, found ${JAVA_VERSION:-no java}: sdk use java $JAVA_SDK"
    [ -n "${TORNADOVM_HOME:-}" ] && [ -d "$TORNADOVM_HOME" ] \
      || die "${JAR##*/} runs on the TornadoVM SDK in TORNADOVM_HOME, which is not set; see Setup once in the README"
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
