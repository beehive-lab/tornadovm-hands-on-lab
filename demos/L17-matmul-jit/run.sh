#!/usr/bin/env bash
# L17 · Matrix multiplication: builds the project and runs MatrixMultiplication, as plain Java while the class is
# plain Java (as committed), and on the GPU through TornadoVM's JIT once you have done steps 1 and 2 of README.md.
# Also writes tornado.args, which the IntelliJ run configurations use. L18 does the AOT part.
#   demos/L17-matmul-jit/run.sh [size] [iterations]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/sdk.sh"
SIZE="${1:-1024}"; ITERATIONS="${2:-5}"

run ./mvnw -q -Dtornadovm.version="$AOT_TORNADOVM_MAVEN" package
if uses_tornadovm; then
  note "MatrixMultiplication calls TornadoVM: JIT-compiled for the GPU"
  run tvm -cp target/matmul.jar "$MAIN" "$SIZE" "$ITERATIONS"
else
  note "MatrixMultiplication is plain Java (steps 1 and 2 of README.md make it a GPU kernel)"
  run "$JAVA" -cp target/matmul.jar "$MAIN" "$SIZE" "$ITERATIONS"
fi
