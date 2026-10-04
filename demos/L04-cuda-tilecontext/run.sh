#!/usr/bin/env bash
# L04 · GEMM on each backend's matrix hardware
#   every backend: the portable @Parallel GEMM
#   metal:         Apple simdgroup_float8x8 matrix units (KernelContext.matrixMultiply8x8)
#   cuda:          the same GEMM with @Parallel, KernelContext and TileContext (CUDA 13.3+, sm_80+)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
N="${1:-1024}"

note "portable: nested @Parallel loops, ${N}x${N}"
tvm -m $EX.compute.MatrixMultiplication2D "$N"

if has_backend metal; then
  note "metal: simdgroup matrix units"
  tvm -m $EX.compute.MatrixMultiplySimdgroup
  tvm --printKernel -m $EX.compute.MatrixMultiplySimdgroup
else
  note "metal variant skipped: needs the Metal backend"
fi

if has_backend cuda; then
  note "cuda: @Parallel vs KernelContext vs TileContext"
  tvm -m $EX.tile.TileMatrixMultiply "$N" 20
  # what a tile task compiles to
  tvm --printKernel -m $EX.tile.TileSoftmax
else
  note "TileContext variant skipped: needs the CUDA backend"
fi
