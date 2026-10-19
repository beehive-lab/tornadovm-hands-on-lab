#!/usr/bin/env bash
# L15 · Your own Maven project: a Java kernel (HelloTornado), then the Hybrid API (FancyHybrid) with the library
# for this platform: Apple MLX on macOS, NVIDIA cuBLAS on a CUDA SDK, none on OpenCL. About 30 seconds after the
# first Maven download.
#   demos/L15-maven-starter/run.sh
# Runs on its own SDK, $STARTER_TORNADOVM_SDK_* (the TornadoVM artifacts on Maven Central are 7.3.1)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"

case "$(uname -s)" in
  Darwin) SDK_ID="$STARTER_TORNADOVM_SDK_MAC";          profile=-Pmlx;    main=com.example.tornado.hybrid.FancyHybridMlx ;;
  *) if has_backend cuda; then
       SDK_ID="$STARTER_TORNADOVM_SDK_LINUX";            profile=-Pcublas; main=com.example.tornado.hybrid.FancyHybrid
     else
       SDK_ID="$STARTER_TORNADOVM_SDK_LINUX_OPENCL";     profile="";       main=""
     fi ;;
esac
STARTER_SDK="${SDKMAN_DIR:-$HOME/.sdkman}/candidates/tornadovm/$SDK_ID"
if [ ! -d "$STARTER_SDK" ]; then
  echo "ERROR: L15 runs on TornadoVM $SDK_ID: sdk install tornadovm $SDK_ID (answer n to making it the default)" >&2
  exit 1
fi
export TORNADOVM_HOME="$STARTER_SDK"
export PATH="$TORNADOVM_HOME/bin:$PATH"

cd "$HERE"
run() { echo "\$ $*"; "$@"; }

# tornado.args: the JVM flags of this SDK, for IntelliJ's run configurations in .run/ (java @tornado.args ...).
# The SDK's own tornado-argfile points at tornadovm/current, so it is generated here for this SDK instead.
# Java does not read argfiles inside an argfile, so the @exportLists files are inlined.
tornado --printJavaFlags | tr ' ' '\n' | sed '1d;/^$/d' | while IFS= read -r flag; do
  case "$flag" in
    @*) grep -v '^#' "${flag#@}" | sed '/^[[:space:]]*$/d' ;;
    *)  echo "$flag" ;;
  esac
done > tornado.args
echo "$JVM_FLAGS" | tr ' ' '\n' >> tornado.args
note "wrote tornado.args for $SDK_ID (IntelliJ run configurations)"

# Maven compiles against the TornadoVM jars from Maven Central; the SDK above runs the code
run ./mvnw -q $profile -Dtornadovm.version="$STARTER_TORNADOVM_MAVEN" package

note "step 1 · HelloTornado: one @Parallel method on the GPU"
run tvm -cp target/classes com.example.tornado.HelloTornado

if [ -z "$main" ]; then
  note "step 2 skipped: the Hybrid API needs MLX (macOS) or cuBLAS (CUDA); this SDK has: ${BACKENDS:-none}"
  exit 0
fi
note "step 2 · ${main##*.}: Java scale -> library gemv -> Java bias, one task graph"
run tvm -cp target/classes "$main"
# a non-square layer: a swapped rows/columns argument to the library shows up here, not with a square one
run tvm -cp target/classes "$main" 300 1000 3
