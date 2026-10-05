# L04 · GEMM on each backend's matrix hardware

The deck shows this on CUDA with `TileContext`. To keep it reproducible everywhere, `run.sh` runs a portable GEMM on every backend, then the variant that uses that backend's own matrix hardware.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | under 100 MB at `n = 1024`; the TornadoVM default (4GB) is plenty |
| Code | in this repo: [`run.sh`](run.sh), using the SDK's built-in `tornado.examples`; on Linux with an NVIDIA GPU, also [beehive-lab/tornadovm-devoxx2026-cuda-demos](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos), [`devoxx/fancyTile.sh`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/blob/main/devoxx/fancyTile.sh) |

| Backend | What runs | Extra requirements |
|---|---|---|
| every backend | `compute.MatrixMultiplication2D`: nested `@Parallel` loops | none |
| Metal | `compute.MatrixMultiplySimdgroup`: Apple `simdgroup_float8x8` matrix units through `KernelContext.matrixMultiply8x8` | Apple Silicon |
| CUDA | `tile.TileMatrixMultiply`: the same GEMM with `@Parallel`, `KernelContext` and `TileContext`, then `--printKernel` on `tile.TileSoftmax` | CUDA 13.3+ with `tileiras`, driver R580+, compute capability 8.0+ |
| OpenCL | the portable GEMM only | none |

## Setup for the CUDA variant

```bash
sdk install tornadovm 7.1.0-jdk22plus-cuda
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

## On Linux with an NVIDIA GPU: `fancyTile.sh`

Linux with an NVIDIA GPU only. The CUDA demos repo has a `devoxx` folder of scripts for the big screen. `fancyTile.sh` runs two acts, each checked: a `KernelContext` kernel, a `TileContext` GEMM, cuBLAS and a `@Parallel` loop captured into one CUDA graph, then an FP16 GEMM ladder of tile shapes against a hand-tuned kernel and cuBLAS, drawn as a bar chart. It takes about 20 seconds.

```bash
git clone https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos.git
cd tornadovm-devoxx2026-cuda-demos/devoxx
bash fancyTile.sh            # NO_PAUSE=1 bash fancyTile.sh to skip the [enter] between acts
```

The script sources the repo's `scripts/setup-env.sh`, compiles the demos it needs and keeps `tornado.recover.bailout` off. It renders with Python 3 (standard library only) and wants a dark terminal at least 100 columns wide with Unicode block characters. It ends with a scoreboard that says `PASSED` only if every check held. If a step fails, its spinner turns into a red `✘` with the path of its log.

The CUDA demos repo selects its SDK in `env/versions.env` (`TORNADO_SDK_PROFILE`), which defaults to **7.0.0**, while this lab uses 7.1.0. Check which one `setup-env.sh` picked before running the demo.
