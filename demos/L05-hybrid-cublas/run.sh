#!/usr/bin/env bash
# L05 · Hybrid API with cuBLAS: clones the CUDA demos repository (first run only) and runs its
# devoxx/fancyHybrid.sh  ·  Linux, NVIDIA GPU, CUDA backend
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
run_cuda_demo "$HERE" fancyHybrid.sh
