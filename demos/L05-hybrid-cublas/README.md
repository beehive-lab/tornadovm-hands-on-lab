# L05 · Hybrid API with cuBLAS

JIT → cuBLAS `sgemv` → JIT in one task graph, on shared device buffers, drawn for the big screen.

**Runs on:** Linux · CUDA only (cuBLAS is an NVIDIA library) · **Needs:** [Setup once](../../README.md#setup-once) · **Code:** [`devoxx/fancyHybrid.sh`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/blob/main/devoxx/fancyHybrid.sh) and [`demos/04-cublas-hybrid`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/tree/main/demos/04-cublas-hybrid) in the CUDA demos repository

## Setup, once

The CUDA demos repository runs on its own pinned SDK, 7.0.0:

```bash
sdk install tornadovm 7.0.0-jdk22plus-cuda       # answer n to making it the default
```

## Run

```bash
demos/L05-hybrid-cublas/run.sh
```

On the first run, the script clones the CUDA demos repository into `demos/L05-hybrid-cublas/tornadovm-devoxx2026-cuda-demos`. It then runs `devoxx/fancyHybrid.sh`, which takes about 10 seconds plus [enter] between the two acts. `NO_PAUSE=1 demos/L05-hybrid-cublas/run.sh` skips the pauses.

It needs Python 3 and a dark terminal at least 100 columns wide.

## You should see

- Act 1: the Java → cuBLAS → Java task graph, run 3 times, with each task's kernel time and every iteration `✔ correct`. `scale` and `bias` are Java; `sgemv` is `CuBlas::cublasSgemv`, a method reference.
- Act 2: 50 executions, plain against `withCUDAGraph()`, as bars.
- A scoreboard ending in `PASSED -- every check holds`. A failed step shows a red `✘` and the path of its log.
