#!/usr/bin/env bash
# L17 phase 2 · The same TornadoVM application, started three ways, and the wall time of each start:
#   jit      java @tornado.args, as in IntelliJ
#   leyden   the same, from a Project Leyden AOT cache (JDK 25+): one training run writes target/matmul.aot
#   native   a GraalVM native image, target/matmul: no JVM at run time (needs GraalVM for JDK 25+, GRAALVM_HOME)
# Needs steps 1 and 2 of README.md done: the class must call TornadoVM.
#   demos/L17-matmul-jit-aot/aot.sh [jit|leyden|native|all] [size]      default: all 256
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/sdk.sh"
MODE="${1:-all}"; SIZE="${2:-256}"
ARGS=("$SIZE" 1)      # a start-up workload: compile the kernel, run it once, check it, exit
RUNS=5                # each start is timed RUNS times; the median is reported

run ./mvnw -q -Dtornadovm.version="$AOT_TORNADOVM_MAVEN" package
uses_tornadovm || { echo "ERROR: MatrixMultiplication is still plain Java: do steps 1 and 2 of README.md first" >&2; exit 1; }

# An AOT cache wants the same class and module paths as its training run, jars only, and no incubator module
# in the boot layer. So the module path gets the runtime's modules only: not ".", and not tornado-unittests or
# tornado-examples, which pull in jdk.incubator.vector. target/aot.args is tornado.args with that module path.
MODS="$HERE/target/tornado-modules"
rm -rf "$MODS" && mkdir -p "$MODS"
for j in "$TORNADOVM_HOME"/share/java/tornado/*.jar; do
  case "$(basename "$j")" in tornado-unittests-*|tornado-examples-*) ;; *) ln -s "$j" "$MODS/" ;; esac
done
awk -v mp="$MODS" 'prev == "--module-path" { $0 = mp } { print; prev = $0 }' tornado.args > target/aot.args

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }
# median_ms CMD...: runs CMD RUNS times, output discarded, and prints the median wall time in ms
median_ms() {
  local times=() r s
  for ((r = 0; r < RUNS; r++)); do
    s=$(now_ms); "$@" >/dev/null 2>&1; times+=($(( $(now_ms) - s )))
  done
  printf '%s\n' "${times[@]}" | sort -n | sed -n "$(( (RUNS + 1) / 2 ))p"
}
RESULTS=()
report() { RESULTS+=("$(printf '%-34s %6s ms' "$1" "$2")"); note "$1: $2 ms (median of $RUNS starts)"; }

JVM=("$JAVA" @target/aot.args -cp target/matmul.jar)
java_feature() { "$JAVA" -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java.specification.version = //p'; }

if [[ $MODE == jit || $MODE == leyden || $MODE == all ]]; then
  note "jit · java @tornado.args: the JVM loads and links every class, then TornadoVM JIT-compiles the kernel"
  run "${JVM[@]}" "$MAIN" "${ARGS[@]}"
  report "jit     java @tornado.args" "$(median_ms "${JVM[@]}" "$MAIN" "${ARGS[@]}")"
fi

if [[ $MODE == leyden || $MODE == all ]]; then
  if [ "$(java_feature)" -lt 25 ]; then
    note "leyden skipped: the AOT cache needs JDK 25 or newer; JAVA_HOME has JDK $(java_feature)"
  else
    note "leyden · training run: records the classes loaded and linked, and method profiles, into target/matmul.aot"
    rm -f target/matmul.aot
    run "${JVM[@]}" -XX:AOTCacheOutput=target/matmul.aot "$MAIN" "${ARGS[@]}"
    note "leyden · production run: starts from the cache (AOTMode=on: a cache that doesn't match is an error)"
    run "${JVM[@]}" -XX:AOTCache=target/matmul.aot -XX:AOTMode=on -Xlog:aot=info "$MAIN" "${ARGS[@]}" \
      | grep -E '^\$|Opened AOT cache|full module graph|Matrix|Device|execution|correct|WRONG' || true
    report "leyden  java -XX:AOTCache" "$(median_ms "${JVM[@]}" -XX:AOTCache=target/matmul.aot -XX:AOTMode=on "$MAIN" "${ARGS[@]}")"
  fi
fi

if [[ $MODE == native || $MODE == all ]]; then
  if [ -z "${GRAALVM_HOME:-}" ]; then
    GRAALVM_HOME="$(ls -d "${SDKMAN_DIR:-$HOME/.sdkman}"/candidates/java/25*graal* 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$GRAALVM_HOME" ] || [ ! -x "$GRAALVM_HOME/bin/native-image" ]; then
    note "native skipped: set GRAALVM_HOME to a GraalVM for JDK 25+ (sdk list java | grep graal)"
  else
    export GRAALVM_HOME
    # GraalVM 25.2 turns on Vector API support, which refuses the shared arenas TornadoVM's drivers use
    # ("Support for Arena.ofShared ... is not available with Vector API support"); TornadoVM does not need it
    export NATIVE_IMAGE_OPTIONS="${NATIVE_IMAGE_OPTIONS:+$NATIVE_IMAGE_OPTIONS }-H:-VectorAPISupport"
    note "native · tracing run on GraalVM's JVM, then native-image: about 30 s"
    run tornado-native-image -cp target/matmul.jar -o target/matmul "$MAIN" "${ARGS[@]}"
    note "native · the executable reads -D options at run time, as the JVM does"
    run target/matmul $JVM_FLAGS "${ARGS[@]}"
    report "native  target/matmul" "$(median_ms target/matmul $JVM_FLAGS "${ARGS[@]}")"
  fi
fi

note "start-up, $SIZE x $SIZE, one execution, wall time of the whole process:"
if [ ${#RESULTS[@]} -gt 0 ]; then printf '   %s\n' "${RESULTS[@]}"; fi
