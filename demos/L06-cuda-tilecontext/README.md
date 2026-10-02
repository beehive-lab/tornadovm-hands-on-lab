# L06 · GEMM on each backend's matrix hardware

The deck shows this on CUDA with `TileContext`. To keep it reproducible everywhere, `run.sh` runs a portable GEMM on every backend, then the variant that uses that backend's own matrix hardware.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | under 100 MB at `n = 1024`; the TornadoVM default (4GB) is plenty |
| Code | in this repo: [`run.sh`](run.sh), using the SDK's built-in `tornado.examples` |

| Backend | What runs | Extra requirements |
|---|---|---|
| every backend | `compute.MatrixMultiplication2D`: nested `@Parallel` loops | none |
| Metal | `compute.MatrixMultiplySimdgroup`: Apple `simdgroup_float8x8` matrix units through `KernelContext.matrixMultiply8x8` | Apple Silicon |
| CUDA | `tile.TileMatrixMultiply`: the same GEMM with `@Parallel`, `KernelContext` and `TileContext`, then `--printKernel` on `tile.TileSoftmax` | CUDA 13.3+ with `tileiras`, driver R580+, compute capability 8.0+ |
| OpenCL | the portable GEMM only | none |

## Setup for the CUDA variant

```bash
sdk install tornadovm 7.0.1-jdk22plus-cuda
pip install --user nvidia-cuda-nvcc 'cuda-tile[tileiras]' nvidia-cuda-cccl
```

## Run

```bash
./run.sh            # n = 1024
./run.sh 2048       # larger matrices
```

## What to look for

- On CUDA, every version reports a correctness check, and `--printKernel` showing `__tile_global__`, `ct::partition_view`, `ct::reduce_max`, with no inline PTX.
- On Metal, `--printKernel` shows the `simdgroup` matrix operations in the generated MSL.

The tile examples check the backend themselves and exit with a message when it is not CUDA. All runs keep `tornado.recover.bailout` off, so a kernel that fails to compile cannot pass by running on the host. On an SDK built with several backends, the variants follow the backends it lists; make sure the default device (`0:0` in `tornado --devices`) is the one you mean.
