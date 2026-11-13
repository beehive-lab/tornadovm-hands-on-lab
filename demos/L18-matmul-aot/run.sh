#!/usr/bin/env bash
# L18 · Matrix multiplication: builds the project and runs it on the GPU with TornadoVM's JIT compiler, as L17 ends.
# aot.sh starts the same application ahead of time. Also writes tornado.args, the JVM flags of L18's SDK.
#   demos/L18-matmul-aot/run.sh [size] [iterations] [kernel]     default 1024 5, Loop Parallel API
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/sdk.sh"

run ./mvnw -q -Dtornadovm.version="$MATMUL_TORNADOVM_MAVEN" package
run tvm -cp target/matmul.jar "$MAIN" "${1:-1024}" "${2:-5}" ${3:+"$3"}
