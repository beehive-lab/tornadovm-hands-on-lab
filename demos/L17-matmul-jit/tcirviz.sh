#!/usr/bin/env bash
# L17 · tcirviz: watch TC, TornadoVM's kernel compiler, turn the matrix multiplication into GPU code, stage by stage.
# Clones and builds tcirviz next to this script on first use, against L17's 8.1.0 SDK. Compiles only: no GPU needed.
#   demos/L17-matmul-jit/tcirviz.sh                 the UI on kernels/MatrixMultiplication.java, the lab's kernel
#   demos/L17-matmul-jit/tcirviz.sh app             the UI on your own class: Open class… lists it, from src/main/java
#   demos/L17-matmul-jit/tcirviz.sh print [backend] [size] [method]
#                                                       the generated kernel in the terminal; metal|opencl|cuda, 1024,
#                                                       matrixMultiplication (or …FloatArray, …Kernel); size ""
#                                                       leaves size unknown when compiling
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/sdk.sh"
MODE="${1:-ui}"

# tcirviz is not in the SDK: build its jar once, and point the tornado launcher at it with TCIRVIZ_JAR.
TCIRVIZ="$HERE/tornadovm-tcirviz"
if [ ! -d "$TCIRVIZ/.git" ]; then
  run git clone -q "$TCIRVIZ_REPO" "$TCIRVIZ"
fi
if [ "$(git -C "$TCIRVIZ" rev-parse HEAD)" != "$(git -C "$TCIRVIZ" rev-parse "$TCIRVIZ_REF^{commit}" 2>/dev/null)" ]; then
  git -C "$TCIRVIZ" fetch -q origin
  run git -C "$TCIRVIZ" checkout -q "$TCIRVIZ_REF"
  rm -f "$TCIRVIZ/build/tcirviz.jar"
fi
[ -f "$TCIRVIZ/build/tcirviz.jar" ] || run "$TCIRVIZ/build.sh"
export TCIRVIZ_JAR="$TCIRVIZ/build/tcirviz.jar"

case "$MODE" in
  ui)
    note "Set size to 1024 in the Arguments row: TornadoVM compiles the kernel for the size it runs with"
    run tornado --tcirviz kernels/MatrixMultiplication.java ;;
  app)
    run ./mvnw -q -Dtornadovm.version="$MATMUL_TORNADOVM_MAVEN" package
    note "Open class… → com.example.matmul.MatrixMultiplication: your version of the exercise"
    PARAMS="--classpath target/matmul.jar --sourcepath src/main/java"
    echo "\$ tornado --tcirviz --params \"$PARAMS\""
    tornado --tcirviz --params "$PARAMS" ;;
  print)
    BACKEND="${2:-metal}"; SIZE="${3-1024}"; METHOD="${4:-matrixMultiplication}"   # SIZE "": not known when compiling
    tornado --tcirviz --params "--json kernels/MatrixMultiplication.java --method $METHOD --backend $BACKEND --arg size=$SIZE" \
      | python3 -c '
import json, sys
trace = json.load(sys.stdin)
for d in trace["diagnostics"]:
    print(d["code"] + ": " + d["message"], file=sys.stderr)
if not trace["ok"]:
    sys.exit(1)
emit = [s for s in trace["functions"][0]["snapshots"] if s["kind"] == "source"][-1]
print("\n".join(line.get("t", "") for line in emit["lines"]).rstrip())' ;;
  *)
    echo "usage: $0 [ui | app | print [metal|opencl|cuda] [size] [method]]" >&2; exit 2 ;;
esac
