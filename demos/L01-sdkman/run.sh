#!/usr/bin/env bash
# L01 · SDKMAN!  ·  any backend
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
tornado --devices
tornado --version
tvm -cp "$TORNADOVM_HOME/share/java/tornado/tornado-examples-$TORNADOVM_VERSION.jar" \
  uk.ac.manchester.tornado.examples.compute.MatrixVectorRowMajor
# the bridge for IDEs, Maven, Gradle and nsys
tornado --generate-argfile
cat "$TORNADOVM_HOME/tornado-argfile"
