# L16 · shared by setup.sh and run.sh. Source it; do not run it.
# Picks this demo's own SDK, $QUARKUS_TORNADOVM_SDK_*, and the clone of the demos repository:
#   JITLLM_QUARKUS_ROOT  a clone of JitLLM-Quarkus-Langchain4j-Demo (default: next to this file)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/lib.sh"

case "$(uname -s)" in
  Darwin) SDK_ID="$QUARKUS_TORNADOVM_SDK_MAC" ;;
  *) if has_backend cuda; then SDK_ID="$QUARKUS_TORNADOVM_SDK_LINUX"; else SDK_ID="$QUARKUS_TORNADOVM_SDK_LINUX_OPENCL"; fi ;;
esac
QUARKUS_SDK="${SDKMAN_DIR:-$HOME/.sdkman}/candidates/tornadovm/$SDK_ID"
if [ ! -d "$QUARKUS_SDK" ]; then
  echo "ERROR: L16 runs on TornadoVM $SDK_ID: sdk install tornadovm $SDK_ID (answer n to making it the default)" >&2
  exit 1
fi
export TORNADOVM_HOME="$QUARKUS_SDK"
export PATH="$TORNADOVM_HOME/bin:$PATH"

# The demos compile for Java 25
JAVA_VERSION="$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.specification\.version = //p')"
[ "${JAVA_VERSION:-0}" -ge 25 ] 2>/dev/null || {
  echo "ERROR: L16 needs JDK 25 or newer, found ${JAVA_VERSION:-no java}: sdk use java $JAVA_SDK" >&2
  exit 1
}

JITLLM_QUARKUS_ROOT="${JITLLM_QUARKUS_ROOT:-$HERE/JitLLM-Quarkus-Langchain4j-Demo}"
run() { echo "\$ $*"; "$@"; }
