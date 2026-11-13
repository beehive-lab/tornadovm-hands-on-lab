# L18 · sourced by run.sh and aot.sh: switches to this demo's TornadoVM SDK and writes tornado.args.
# L18 runs on its own SDK, $AOT_TORNADOVM_SDK_*: the Leyden AOT cache and tornado-native-image ship from 8.0.0.
source "$HERE/../../scripts/lib.sh"

case "$(uname -s)" in
  Darwin) SDK_ID="$AOT_TORNADOVM_SDK_MAC" ;;
  *) if has_backend cuda; then SDK_ID="$AOT_TORNADOVM_SDK_LINUX"; else SDK_ID="$AOT_TORNADOVM_SDK_LINUX_OPENCL"; fi ;;
esac
L18_SDK="${SDKMAN_DIR:-$HOME/.sdkman}/candidates/tornadovm/$SDK_ID"
if [ ! -d "$L18_SDK" ]; then
  echo "ERROR: L18 runs on TornadoVM $SDK_ID: sdk install tornadovm $SDK_ID (answer n to making it the default)" >&2
  exit 1
fi
export TORNADOVM_HOME="$L18_SDK"
export PATH="$TORNADOVM_HOME/bin:$PATH"
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"

cd "$HERE"
run() { echo "\$ $*"; "$@"; }
MAIN=com.example.matmul.MatrixMultiplication

# tornado.args: the JVM flags of this SDK, one per line, for aot.sh.
# The SDK's own tornado-argfile points at tornadovm/current, so it is generated here for this SDK instead.
# Java does not read argfiles inside an argfile, so the @exportLists files are inlined.
tornado --printJavaFlags | tr ' ' '\n' | sed '1d;/^$/d' | while IFS= read -r flag; do
  case "$flag" in
    @*) grep -v '^#' "${flag#@}" | sed '/^[[:space:]]*$/d' ;;
    *)  echo "$flag" ;;
  esac
done > tornado.args
echo "$JVM_FLAGS" | tr ' ' '\n' >> tornado.args
note "wrote tornado.args for $SDK_ID"
