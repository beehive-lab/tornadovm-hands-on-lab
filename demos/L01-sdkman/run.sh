#!/usr/bin/env bash
# L01 · SDKMAN!  ·  any backend
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
tornado --devices
tornado --version
tvm -m $EX.VectorAddInt 100000
# the bridge for IDEs, Maven, Gradle and nsys
tornado --generate-argfile
cat "$TORNADOVM_HOME/tornado-argfile"
