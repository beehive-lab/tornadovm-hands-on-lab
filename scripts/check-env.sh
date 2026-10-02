#!/usr/bin/env bash
# Checks the TornadoVM SDK, lists GPUs and their memory, and says which demos apply here.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/env/versions.env"

OS="$(uname -s)"
case "$OS" in
  Darwin) SDK="$TORNADOVM_SDK_MAC" ;;
  *)      SDK="$TORNADOVM_SDK_LINUX (NVIDIA) or $TORNADOVM_SDK_LINUX_OPENCL (Intel, AMD)" ;;
esac

if ! command -v tornado >/dev/null 2>&1 || [ -z "${TORNADOVM_HOME:-}" ]; then
  echo "TornadoVM is not on this shell's PATH."
  echo "Install:  sdk install java $JAVA_SDK  &&  sdk install tornadovm <one of: $SDK>"
  exit 1
fi

BACKENDS="$(sed -n 's/^tornado\.backends=//p' "$TORNADOVM_HOME/etc/tornado.backend" 2>/dev/null | tr ',' ' ' | sed 's/-backend//g')"

echo "== OS              $OS"
echo "== java            $(java -version 2>&1 | head -1)"
echo "== TORNADOVM_HOME  $TORNADOVM_HOME"
echo "== backends        ${BACKENDS:-unknown}"
echo "== tornado --devices"; tornado --devices

echo "== GPU memory"
if [ "$OS" = Darwin ]; then
  echo "   unified memory: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB shared by CPU and GPU;"
  echo "   macOS lets the GPU use only part of it, so leave headroom for large models."
elif command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader | sed 's/^/   /'
else
  echo "   nvidia-smi not found; check your vendor's tool (e.g. clinfo) for device memory."
fi
echo "   TornadoVM budget: ${TORNADO_DEVICE_MEMORY:-4GB (default)}   jitLLM budget: $JITLLM_GPU_MEMORY"

echo "== demos for this platform"
for b in $BACKENDS; do
  case "$b" in
    metal)  echo "   metal:  L01-L06 (L06 runs the simdgroup GEMM), L08-L10, L13" ;;
    cuda)   echo "   cuda:   all of L01-L13 (L11-L12 also need RAPIDS and the Flink repo)" ;;
    opencl) echo "   opencl: L01-L06 (L06 runs the portable GEMM only), L08-L10, L13" ;;
  esac
done
