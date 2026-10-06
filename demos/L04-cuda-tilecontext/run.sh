#!/usr/bin/env bash
# L04 · CUDA TileContext: clones the CUDA demos repository (first run only) and runs its
# devoxx/fancyTile.sh  ·  Linux, NVIDIA GPU, CUDA backend
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
run_cuda_demo "$HERE" fancyTile.sh
