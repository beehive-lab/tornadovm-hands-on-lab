#!/usr/bin/env bash
# L17 phase 2 · The same TornadoVM application, started three ways, drawn for the big screen, one act per start:
#   1. jit      java @tornado.args, as in IntelliJ
#   2. leyden   the same, from a Project Leyden AOT cache (JDK 25+): one training run writes target/matmul.aot
#   3. native   a GraalVM native image, target/matmul: no JVM at run time (needs GraalVM for JDK 25+, GRAALVM_HOME)
# then the three starts side by side, and the checks. Every step's output is in target/logs/.
# Needs steps 1 and 2 of README.md done: the class must call TornadoVM.
#   demos/L17-matmul-jit-aot/aot.sh [jit|leyden|native|all] [size]      default: all 256
#   NO_PAUSE=1 skips the [enter] between acts · NO_COLOR=1 draws without colors · RUNS=n times n starts (default 5)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/sdk.sh" > /dev/null
MODE="${1:-all}"; SIZE="${2:-256}"
case "$MODE" in jit|leyden|native|all) ;; *) echo "usage: aot.sh [jit|leyden|native|all] [size]" >&2; exit 2 ;; esac
ARGS=("$SIZE" 1)      # a start-up workload: compile the kernel, run it once, check it, exit
RUNS="${RUNS:-5}"     # each start is timed RUNS times; the median is reported

FANCY="python3 $HERE/fancy.py"
LOGS="$HERE/target/logs"
STARTS="$LOGS/starts.tsv"     # mode, wall ms, first execute() ms, PASS|FAIL: one row per timed start
CHECKS="$LOGS/checks.tsv"     # PASS|FAIL|SKIP, text
TTY=; [ -t 1 ] && TTY=1
[ -n "$TTY" ] || export NO_COLOR=1
c() { [ -n "${NO_COLOR:-}" ] && printf '%s' "$2" || printf '\033[%sm%s\033[0m' "$1" "$2"; }   # c CODE TEXT

# shown CMD...: the command as typed in this folder, without the JDK's path
shown() { local s="$*"; s="${s//$HERE\//}"; [ -n "${JAVA_HOME:-}" ] && s="${s//$JAVA_HOME\/bin\//}"; printf '%s' "$s"; }

# spin LABEL LOG COMMAND...: runs the command with its output in LOG, animating one status line until it ends
spin() {
  local label="$1" log="$2"; shift 2
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' start=$SECONDS i=0 status=0
  echo "      $(c 2 "\$ $(shown "$@")")"
  ( "$@" ) < /dev/null > "$log" 2>&1 &
  local pid=$!
  while [ -n "$TTY" ] && kill -0 "$pid" 2>/dev/null; do
    printf '\r    %s %-58s %s ' "$(c '1;36' "${frames:i++%10:1}")" "$label" "$(c 2 "$(printf '%3ds' $((SECONDS - start)))")"
    sleep 0.1
  done
  wait "$pid" || status=$?
  if [ "$status" -eq 0 ]; then
    printf '\r    %s %-58s %s \n' "$(c '1;32' ✔)" "$label" "$(c 2 "$(printf '%3ds' $((SECONDS - start)))")"
  else
    printf '\r    %s %-58s %s\n' "$(c '1;31' ✘)" "$label" "$(c 2 "$(printf '%3ds  (log: %s)' $((SECONDS - start)) "$log")")"
  fi
  return "$status"
}

check() { printf '%s\t%s\n' "$1" "$2" >> "$CHECKS"; }   # check PASS|FAIL|SKIP TEXT
# check_log LOG PATTERN TEXT: PASS if LOG matches PATTERN
check_log() { if grep -qE "$2" "$1"; then check PASS "$3"; else check FAIL "$3   (log: $1)"; fi; }

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }
# time_starts MODE COMMAND...: starts the program RUNS times, printing each wall time as it comes, into $STARTS
time_starts() {
  local mode=$1; shift
  local r s ms first ok log
  echo "      $(c 2 "\$ $(shown "$@")")"
  printf '    %s' "$(c 1 "$RUNS starts, ms:")"
  for ((r = 1; r <= RUNS; r++)); do
    log="$LOGS/$mode-start-$r.log"
    s=$(now_ms); ok=PASS
    "$@" < /dev/null > "$log" 2>&1 || ok=FAIL
    ms=$(( $(now_ms) - s ))
    grep -q 'Result is correct' "$log" || ok=FAIL
    first=$(sed -n 's/^ *execution 0: *\([0-9.]*\) ms.*/\1/p' "$log" | head -1)
    printf '%s\t%s\t%s\t%s\n' "$mode" "$ms" "${first:-0}" "$ok" >> "$STARTS"
    if [ "$ok" = PASS ]; then printf '  %s' "$(c '1;32' "$ms")"; else printf '  %s' "$(c '1;31' "${ms}✘")"; fi
  done
  echo
  $FANCY starts "$STARTS" "$mode"
}
# [enter] between acts, only in a terminal and unless NO_PAUSE is set
pause() { [ -n "${NO_PAUSE:-}" ] || ! [ -t 0 ] || [ -z "$TTY" ] || read -r -p "$(c 2 '    [enter] next ')" _ || echo; }

java_feature() { "$JAVA" -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java.specification.version = //p'; }
JDK="$("$JAVA" -version 2>&1 | sed -n '1s/.*version "\([^"]*\)".*/\1/p')"
case "$(uname -s)" in
  Darwin) GPU="$(sysctl -n machdep.cpu.brand_string)" ;;
  *) GPU="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)"; GPU="${GPU:-$(uname -m)}" ;;
esac
if [ -z "${GRAALVM_HOME:-}" ]; then
  GRAALVM_HOME="$(ls -d "${SDKMAN_DIR:-$HOME/.sdkman}"/candidates/java/25*graal* 2>/dev/null | head -1 || true)"
fi

mkdir -p "$LOGS"; : > "$STARTS"; : > "$CHECKS"
$FANCY banner "Matrix multiplication · JIT, a Leyden AOT cache, a GraalVM native image" \
  "TornadoVM ${SDK_ID%%-*} · ${BACKENDS:-?} · $GPU · JDK $JDK · $SIZE × $SIZE, $RUNS starts each"
echo

spin "build target/matmul.jar" "$LOGS/build.log" ./mvnw -q -Dtornadovm.version="$AOT_TORNADOVM_MAVEN" package \
  || { tail -20 "$LOGS/build.log" >&2; exit 1; }
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
JVM=(java @target/aot.args -cp target/matmul.jar)
[ -n "${JAVA_HOME:-}" ] && JVM[0]="$JAVA_HOME/bin/java"

ACT=0
BACKEND_NAME="$(case "${BACKENDS%% *}" in cuda) echo CUDA;; opencl) echo OpenCL;; metal) echo Metal;; *) echo "${BACKENDS:-GPU}";; esac)"
if [[ $MODE == jit || $MODE == leyden || $MODE == all ]]; then
  $FANCY act $((ACT += 1)) "JIT" "every start pays for it all: the JVM loads and links TornadoVM's classes, then TC compiles the kernel"
  $FANCY pipeline "java:JVM starts" "load + link:TornadoVM, $BACKEND_NAME" "TC:Java → GPU code" "GPU:execute()"
  time_starts jit "${JVM[@]}" "$MAIN" "${ARGS[@]}"
  check "$(grep -q $'^jit\t.*\tFAIL$' "$STARTS" && echo FAIL || echo PASS)" "jit: every start computes the right result"
fi

if [[ $MODE == leyden || $MODE == all ]]; then
  [ "$ACT" -gt 0 ] && pause
  $FANCY act $((ACT += 1)) "Project Leyden AOT cache" "a training run stores the classes loaded and linked, and method profiles; every later start maps them in"
  $FANCY pipeline "training run:-XX:AOTCacheOutput" "matmul.aot:classes, linked" "every start:-XX:AOTCache"
  if [ "$(java_feature)" -lt 25 ]; then
    echo "    $(c 2 "skipped: the AOT cache needs JDK 25 or newer; JAVA_HOME has JDK $(java_feature)")"; echo
    check SKIP "leyden: needs JDK 25+, this is JDK $(java_feature)"
  else
    rm -f target/matmul.aot
    if spin "training run: writes target/matmul.aot" "$LOGS/leyden-training.log" \
         "${JVM[@]}" -XX:AOTCacheOutput=target/matmul.aot "$MAIN" "${ARGS[@]}" && [ -f target/matmul.aot ]; then
      echo "      $(c 2 "target/matmul.aot: $(du -h target/matmul.aot | cut -f1 | tr -d ' ')")"
      # AOTMode=on: a cache that doesn't match the run is an error, not a silent slow start
      spin "production run, with -Xlog:aot" "$LOGS/leyden-check.log" \
        "${JVM[@]}" -XX:AOTCache=target/matmul.aot -XX:AOTMode=on -Xlog:aot=info "$MAIN" "${ARGS[@]}" || true
      for p in 'Opened AOT cache' 'full module graph: enabled'; do
        grep -q "$p" "$LOGS/leyden-check.log" && echo "      $(c '1;32' ✔) $(c 2 "$p")" || echo "      $(c '1;31' ✘) $(c 2 "no \"$p\"")"
      done
      echo
      check_log "$LOGS/leyden-check.log" 'Opened AOT cache' "leyden: the JVM opens the cache (AOTMode=on)"
      check_log "$LOGS/leyden-check.log" 'full module graph: enabled' "leyden: TornadoVM's module graph comes from the cache"
      time_starts leyden "${JVM[@]}" -XX:AOTCache=target/matmul.aot -XX:AOTMode=on "$MAIN" "${ARGS[@]}"
      check "$(grep -q $'^leyden\t.*\tFAIL$' "$STARTS" && echo FAIL || echo PASS)" "leyden: every start computes the right result"
    else
      echo; check FAIL "leyden: the training run writes target/matmul.aot   (log: $LOGS/leyden-training.log)"
    fi
  fi
fi

if [[ $MODE == native || $MODE == all ]]; then
  [ "$ACT" -gt 0 ] && pause
  $FANCY act $((ACT += 1)) "GraalVM native image" "the application, TornadoVM's runtime, the $BACKEND_NAME backend and TC, compiled into one executable: no JVM"
  $FANCY pipeline "tracing run:native-image agent" "native-image:build, ~30 s" "target/matmul:no JVM"
  if [ -z "$GRAALVM_HOME" ] || [ ! -x "$GRAALVM_HOME/bin/native-image" ]; then
    echo "    $(c 2 "skipped: set GRAALVM_HOME to a GraalVM for JDK 25+ (sdk list java | grep graal)")"; echo
    check SKIP "native: needs GRAALVM_HOME, a GraalVM for JDK 25+"
  else
    export GRAALVM_HOME
    # GraalVM 25.2 turns on Vector API support, which refuses the shared arenas TornadoVM's drivers use
    # ("Support for Arena.ofShared ... is not available with Vector API support"); TornadoVM does not need it
    export NATIVE_IMAGE_OPTIONS="${NATIVE_IMAGE_OPTIONS:+$NATIVE_IMAGE_OPTIONS }-H:-VectorAPISupport"
    echo "    $(c 2 "GraalVM: $(basename "$GRAALVM_HOME")")"
    rm -f target/matmul
    if spin "tracing run on GraalVM's JVM, then native-image" "$LOGS/native-build.log" \
         tornado-native-image -cp target/matmul.jar -o target/matmul "$MAIN" "${ARGS[@]}" && [ -x target/matmul ]; then
      echo "      $(c 2 "target/matmul: $(du -h target/matmul | cut -f1 | tr -d ' '), reads -D options at run time as the JVM does")"
      echo
      check PASS "native: target/matmul builds"
      # shellcheck disable=SC2086
      time_starts native target/matmul $JVM_FLAGS "${ARGS[@]}"
      check "$(grep -q $'^native\t.*\tFAIL$' "$STARTS" && echo FAIL || echo PASS)" "native: every start computes the right result"
    else
      echo; check FAIL "native: target/matmul builds   (log: $LOGS/native-build.log)"
    fi
  fi
fi

pause
$FANCY compare "$STARTS" "$CHECKS" "start-up, $SIZE × $SIZE, one execution: wall time of the whole process, median of $RUNS"
