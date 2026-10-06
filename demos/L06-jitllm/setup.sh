#!/usr/bin/env bash
# L06 · one-time setup for L06-L10: clones jitLLM, builds it against the TornadoVM SDK in
# TORNADOVM_HOME, and downloads the model. Steps already done are skipped.
#   ./setup.sh
# Prints every command before it runs it.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
run() { echo "\$ $*"; "$@"; }

JITLLM_ROOT="${JITLLM_ROOT:-$HERE/jitllm}"
MODEL="${JITLLM_MODEL_DIR:-$JITLLM_ROOT}/$JITLLM_MODEL"

if [ ! -d "$JITLLM_ROOT/.git" ]; then
  run git clone -b "$JITLLM_REF" "$JITLLM_REPO" "$JITLLM_ROOT"
fi
run cd "$JITLLM_ROOT"

if ls target/jitllm-*.jar >/dev/null 2>&1; then
  note "jitLLM already built; delete $JITLLM_ROOT/target to build it again"
else
  # Compiles against, and later runs on, the SDK in TORNADOVM_HOME. The build's SDK check rejects
  # a path through a symlink, such as SDKMAN!'s candidates/tornadovm/current, so resolve it.
  export TORNADOVM_HOME="$(cd "$TORNADOVM_HOME" && pwd -P)"
  run ./mvnw -q clean package -DskipTests || {
    echo "ERROR: the build failed. A clone made before jitLLM built against the SDK fails here;" >&2
    echo "       update it (git -C $JITLLM_ROOT pull) or delete it and run this script again." >&2
    exit 1
  }
fi

if [ -f "$MODEL" ]; then
  note "model already downloaded: $MODEL"
else
  # -C - resumes an interrupted download
  run curl -L --fail -C - -o "$MODEL.part" "$JITLLM_MODEL_URL"
  run mv "$MODEL.part" "$MODEL"
fi

echo "Ready. Next: $HERE/jitllm.sh --prompt \"Explain GPU acceleration in one sentence.\""
