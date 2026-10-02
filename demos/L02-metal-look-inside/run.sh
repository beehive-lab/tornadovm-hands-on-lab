#!/usr/bin/env bash
# L02 · Run on Metal, then look inside  ·  any backend (MSL on Metal, CUDA C on CUDA, OpenCL C on OpenCL)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../scripts/lib.sh"
tornado --devices
tvm -m $EX.VectorAddInt 100000
# the kernel the JIT generated for this backend
tvm --printKernel -m $EX.VectorAddInt 1024
# TornadoVM's own runtime bytecodes
tvm --printBytecodes -m $EX.VectorAddInt 1024
