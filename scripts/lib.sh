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
