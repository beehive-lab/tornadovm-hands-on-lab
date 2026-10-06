# Shared helpers for the demo scripts. Source it; do not run it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env/versions.env"

if [ -z "${TORNADOVM_HOME:-}" ] || ! command -v tornado >/dev/null 2>&1; then
  echo "TornadoVM SDK not found. Run scripts/check-env.sh first." >&2
  exit 1
fi

# Installed backends, from the SDK itself, e.g. "cuda" or "metal opencl".
BACKENDS="$(sed -n 's/^tornado\.backends=//p' "$TORNADOVM_HOME/etc/tornado.backend" 2>/dev/null \
            | tr ',' ' ' | sed 's/-backend//g')"
has_backend() { [[ " $BACKENDS " == *" $1 "* ]]; }

# Exit code 3 = the demo does not apply to this platform (reported as SKIP by run-all.sh).
skip() { echo "SKIP: $*"; exit 3; }
note() { echo "-- $*"; }

# JVM flags for every demo run:
#  - bailout off, so a kernel that fails to compile fails loudly instead of silently
#    running on the host and looking like a pass;
#  - the device memory budget, when TORNADO_DEVICE_MEMORY is set.
JVM_FLAGS="-Dtornado.recover.bailout=False"
if [ -n "$TORNADO_DEVICE_MEMORY" ]; then
  JVM_FLAGS="$JVM_FLAGS -Dtornado.device.memory=$TORNADO_DEVICE_MEMORY"
fi
tvm() { tornado --jvm="$JVM_FLAGS" "$@"; }

EX=tornado.examples/uk.ac.manchester.tornado.examples
note "backends: ${BACKENDS:-unknown} · device memory: ${TORNADO_DEVICE_MEMORY:-4GB (TornadoVM default)}"

# run_cuda_demo DIR SCRIPT: clones the CUDA demos repository into DIR/tornadovm-devoxx2026-cuda-demos
# (first run only) and runs devoxx/SCRIPT from there (L04 fancyTile.sh, L05 fancyHybrid.sh).
# In a terminal it runs as on stage, with [enter] between acts. Without one (scripts/run-all.sh),
# it skips the pauses and passes only if the scoreboard does: the script's exit code does not say.
run_cuda_demo() {
  local demos="$1/tornadovm-devoxx2026-cuda-demos" script=$2
  has_backend cuda || skip "$script needs an NVIDIA GPU and the CUDA backend; this SDK has: ${BACKENDS:-none}"
  if [ ! -d "$demos/.git" ]; then
    echo "\$ git clone $CUDA_DEMOS_REPO $demos"
    git clone "$CUDA_DEMOS_REPO" "$demos"
  fi
  # The CUDA demos repository runs on its own pinned SDK, not on the lab's.
  if [ ! -d "${SDKMAN_DIR:-$HOME/.sdkman}/candidates/tornadovm/$CUDA_DEMOS_TORNADOVM_SDK" ]; then
    echo "ERROR: $script runs on TornadoVM $CUDA_DEMOS_TORNADOVM_SDK: sdk install tornadovm $CUDA_DEMOS_TORNADOVM_SDK (answer n to making it the default)" >&2
    exit 1
  fi
  echo "\$ cd $demos/devoxx"
  cd "$demos/devoxx"
  echo "\$ bash $script"
  if [ -t 0 ] && [ -t 1 ]; then
    exec bash "$script"
  fi
  NO_PAUSE=1 bash "$script" | tee /dev/stderr | grep 'PASSED -- every check holds' >/dev/null
}
