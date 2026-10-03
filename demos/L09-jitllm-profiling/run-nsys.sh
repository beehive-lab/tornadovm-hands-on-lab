#!/usr/bin/env bash
# L09 · jitLLM under Nsight Systems: writes a .nsys-rep and prints the kernel summary  ·  NVIDIA GPU, CUDA backend
#   ./run-nsys.sh [--cuda-graphs] [max-new-tokens]    default 30 tokens
#     (default)       jitllm.nsys-rep: one kernel launch at a time
#     --cuda-graphs   jitllm-graphs.nsys-rep: each token replayed as one CUDA graph; nsys traces
#                     the kernels inside it (--cuda-graph-trace=node), so the two timelines compare
# The launcher starts the JVM as a child process; nsys follows it, so the kernels show up
# under the names of the Java methods TornadoVM compiled them from.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/jitllm.sh"

OUT="$HERE/jitllm"
NSYS_FLAGS=(--trace=cuda,nvtx,osrt)
JITLLM_FLAGS=()
if [ "${1:-}" = --cuda-graphs ]; then
  shift
  OUT="$HERE/jitllm-graphs"
  NSYS_FLAGS+=(--cuda-graph-trace=node)
  JITLLM_FLAGS+=(--cuda-graphs)
fi
TOKENS="${1:-30}"

# Nsight Systems records CUDA activity: with Metal or OpenCL it would find no kernels.
BACKENDS="$(sed -n 's/^tornado\.backends=//p' "$TORNADOVM_HOME/etc/tornado.backend" 2>/dev/null || true)"
[[ "$BACKENDS" == *cuda* ]] \
  || die "run-nsys.sh needs an NVIDIA GPU and TornadoVM's CUDA backend; ${TORNADOVM_HOME} has: ${BACKENDS:-no backend file}"
command -v nsys >/dev/null 2>&1 \
  || die "nsys not found: Nsight Systems ships with the CUDA toolkit (Linux · NVIDIA), e.g. /usr/local/cuda/bin"

JITLLM_PREFIX=(nsys profile "${NSYS_FLAGS[@]}" --force-overwrite=true -o "$OUT")
run_jitllm "$HERE/jitllm.log" ${JITLLM_FLAGS[@]+"${JITLLM_FLAGS[@]}"} \
  --prompt "Explain GPU acceleration in one sentence." --max-new-tokens "$TOKENS"

note "GPU kernels, by total time"
nsys stats --force-export=true --report cuda_gpu_kern_sum "$OUT.nsys-rep" 2>/dev/null \
  | sed -n '/Time (%)/,$p' | head -14
echo "Wrote $OUT.nsys-rep; open the timeline with: nsys-ui $OUT.nsys-rep"
