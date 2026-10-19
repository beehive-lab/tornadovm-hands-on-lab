#!/usr/bin/env bash
# L14 · Hybrid API with Apple MLX, drawn for the big screen, in two acts, as L05 (fancyHybrid.sh). About 10 seconds.
#   1. L15's FancyHybridMlx: Java scale -> Mlx::matmul -> Java bias, the kernel time of each task
#   2. a GEMM, where the library pulls ahead: a @Parallel Java SGEMM against Mlx::matmul
#   demos/L14-hybrid-mlx/run.sh       NO_PAUSE=1 to skip the [enter] between acts
# macOS, Apple Silicon · runs on its own SDK, $MLX_TORNADOVM_SDK, the one L15 is built against
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"

[ "$(uname -s)" = Darwin ] || skip "MLX runs on Apple Silicon only; this is $(uname -s)"
MLX_SDK="${SDKMAN_DIR:-$HOME/.sdkman}/candidates/tornadovm/$MLX_TORNADOVM_SDK"
if [ ! -f "$MLX_SDK/share/java/tornado/tornado-mlx-${MLX_TORNADOVM_SDK%%-*}.jar" ]; then
  echo "ERROR: L14 runs on TornadoVM $MLX_TORNADOVM_SDK: sdk install tornadovm $MLX_TORNADOVM_SDK (answer n to making it the default)" >&2
  exit 1
fi
export TORNADOVM_HOME="$MLX_SDK"
export PATH="$TORNADOVM_HOME/bin:$PATH"

FANCY="python3 $HERE/fancy.py"
FANCY_LOGS="$(mktemp -d)"
export FANCY_STATE="$FANCY_LOGS/scoreboard.tsv"
: > "$FANCY_STATE"
GPU="$(sysctl -n machdep.cpu.brand_string)"

# spin LABEL LOG COMMAND...: runs the command with its output in LOG, animating one status line until it ends
spin() {
  local label="$1" log="$2"; shift 2
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' start=$SECONDS i=0
  ( "$@" ) < /dev/null > "$log" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r    \033[1;36m%s\033[0m %-44s \033[2m%3ds\033[0m ' "${frames:i++%10:1}" "$label" $((SECONDS - start))
    sleep 0.1
  done
  local status=0
  wait "$pid" || status=$?
  if [ "$status" -eq 0 ]; then
    printf '\r    \033[1;32m✔\033[0m %-44s \033[2m%3ds\033[0m \n' "$label" $((SECONDS - start))
  else
    printf '\r    \033[1;31m✘\033[0m %-44s \033[2m%3ds  (log: %s)\033[0m\n' "$label" $((SECONDS - start)) "$log"
  fi
  return "$status"
}
# [enter] between acts, only in a terminal and unless NO_PAUSE is set
fancy_pause() { [ -n "${NO_PAUSE:-}" ] || ! [ -t 0 ] || read -r -p $'\033[2m    [enter] next \033[0m' _ || echo; }

L15="$HERE/../L15-maven-starter"
(cd "$L15" && ./mvnw -q -Pmlx -Dtornadovm.version="$STARTER_TORNADOVM_MAVEN" package)
mkdir -p "$HERE/build"
javac -proc:none -cp "$(ls "$TORNADOVM_HOME"/share/java/tornado/*.jar | tr '\n' ':')" -d "$HERE/build" "$HERE"/src/*.java
cd "$HERE/build"

$FANCY banner "Hybrid API · Java kernels + Apple MLX, one task graph" \
  "TornadoVM ${MLX_TORNADOVM_SDK%%-*} · Metal · $GPU · checked against the CPU"

$FANCY act 1 "L15's FancyHybridMlx" "the class from IntelliJ: two Java kernels compiled to Metal, Mlx::matmul between, shared buffers"
spin "a 2048 × 4096 layer, 5 executions, profiler on" "$FANCY_LOGS/layer.log" \
  tvm --enableProfiler console --classpath "$L15/target/classes" com.example.tornado.hybrid.FancyHybridMlx 2048 4096 5 || true
$FANCY hybrid-layer "$FANCY_LOGS/layer.log"
fancy_pause

$FANCY act 2 "Where the library wins" "a GEMM does 2N flops per element: the same SGEMM as a @Parallel Java kernel and as Mlx::matmul"
spin "20 executions each, Java kernel and MLX" "$FANCY_LOGS/gemm.log" \
  tvm --classpath . MlxGemmBenefit 2048 20 || true
$FANCY hybrid-gemm "$FANCY_LOGS/gemm.log"

$FANCY scoreboard "Hybrid API on the $GPU" | tee "$FANCY_LOGS/scoreboard.txt"
grep -q 'PASSED -- every check holds' "$FANCY_LOGS/scoreboard.txt"
