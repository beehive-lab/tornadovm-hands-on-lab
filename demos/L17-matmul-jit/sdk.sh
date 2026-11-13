# L17 · sourced by run.sh and tcirviz.sh: switches to this demo's TornadoVM SDK and writes tornado.args.
# L17 runs on its own SDK, $MATMUL_TORNADOVM_SDK_*, shared with L18: TC and tcirviz need 8.0.0+.
source "$HERE/../../scripts/lib.sh"

case "$(uname -s)" in
  Darwin) SDK_ID="$MATMUL_TORNADOVM_SDK_MAC" ;;
  *) if has_backend cuda; then SDK_ID="$MATMUL_TORNADOVM_SDK_LINUX"; else SDK_ID="$MATMUL_TORNADOVM_SDK_LINUX_OPENCL"; fi ;;
esac
L17_SDK="${SDKMAN_DIR:-$HOME/.sdkman}/candidates/tornadovm/$SDK_ID"
if [ ! -d "$L17_SDK" ]; then
  echo "ERROR: L17 runs on TornadoVM $SDK_ID: sdk install tornadovm $SDK_ID (answer n to making it the default)" >&2
  exit 1
fi
export TORNADOVM_HOME="$L17_SDK"
export PATH="$TORNADOVM_HOME/bin:$PATH"
read_backends   # BACKENDS so far were the default SDK's; from here on, this SDK's
note "L17 runs on TornadoVM $SDK_ID · backends: ${BACKENDS:-unknown}"
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"

cd "$HERE"
run() { echo "\$ $*"; "$@"; }
MAIN=com.example.matmul.MatrixMultiplication
# true once the class calls TornadoVM, that is, after steps 1 and 2 of the exercise
uses_tornadovm() { grep -q 'uk/ac/manchester/tornado' target/classes/com/example/matmul/MatrixMultiplication.class; }

# tornado.args: the JVM flags of this SDK, one per line, for IntelliJ (VM options: @tornado.args).
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
