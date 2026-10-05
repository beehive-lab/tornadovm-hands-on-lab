# L04 · GEMM on each backend's matrix hardware

The deck shows this on CUDA with `TileContext`. To keep it reproducible everywhere, `run.sh` runs a portable GEMM on every backend, then the variant that uses that backend's own matrix hardware.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | under 100 MB at `n = 1024`; the TornadoVM default (4GB) is plenty |
| Code | in this repo: [`run.sh`](run.sh), using the SDK's built-in `tornado.examples`; on CUDA, also [beehive-lab/tornadovm-devoxx2026-cuda-demos](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos), [`demos/25-tile-ladder`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/tree/main/demos/25-tile-ladder) (class `TileLadder`) |

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

## On CUDA: the TileContext ladder (demo 25)

Demo 25 of the CUDA demos repo takes the same FP16 GEMM further: a simple and a fully optimised `KernelContext` kernel, a ten-line `TileContext` kernel climbed over tile shapes and the `occupancy=2` launch hint, and cuBLAS as the ceiling. Every rung is validated against a CPU reference.

```bash
git clone https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos.git
cd tornadovm-devoxx2026-cuda-demos
source scripts/setup-env.sh          # JAVA_HOME, TORNADOVM_HOME, PATH, argfile
cd demos/25-tile-ladder
javac -cp "$TORNADOVM_HOME/share/java/tornado/*" -d . TileLadder.java
tornado --jvm="-Dtornado.recover.bailout=False" --classpath . TileLadder 2048 10
```

Arguments are `<n> <executions>`; `n` must be a multiple of 128 (default 2048). The plain-`java` form is `java @$TORNADOVM_HOME/tornado-argfile -Dtornado.recover.bailout=False -cp . TileLadder 2048 10`.

- The program ends with `All rungs produced the same, correct result`.
- It prints wall clock, which the 16 MB copy-back flattens. Compare rungs on kernel time, with the `nsys` commands in the [demo's README](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/tree/main/demos/25-tile-ladder#kernel-time--the-honest-comparison).
- A tile rung that prints `PASSED` but takes seconds ran on the host: `-Dtornado.recover.bailout=False` is missing.

The CUDA demos repo selects its SDK in `env/versions.env` (`TORNADO_SDK_PROFILE`), which defaults to **7.0.0**, while this lab uses 7.1.0. Check which one `setup-env.sh` picked before running the demo.
