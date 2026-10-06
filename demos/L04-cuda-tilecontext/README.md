# L04 · CUDA TileContext

Threads, tiles and cuBLAS in one CUDA graph, then a ladder of tile shapes against a hand-tuned kernel and cuBLAS, drawn for the big screen.

**Runs on:** Linux · CUDA only · **Needs:** [Setup once](../../README.md#setup-once) · **Code:** [`devoxx/fancyTile.sh`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/blob/main/devoxx/fancyTile.sh) in the CUDA demos repository

## Setup, once

The CUDA demos repository runs on its own pinned SDK, 7.0.0. It also needs CUDA 13.3+ with `tileiras`, driver R580+ and compute capability 8.0+:

```bash
sdk install tornadovm 7.0.0-jdk22plus-cuda       # answer n to making it the default
pip install --user nvidia-cuda-nvcc 'cuda-tile[tileiras]' nvidia-cuda-cccl
```

## Run

```bash
demos/L04-cuda-tilecontext/run.sh
```

On the first run, the script clones the CUDA demos repository into `demos/L04-cuda-tilecontext/tornadovm-devoxx2026-cuda-demos`. It then runs `devoxx/fancyTile.sh`, which takes about 20 seconds plus [enter] between the two acts. `NO_PAUSE=1 demos/L04-cuda-tilecontext/run.sh` skips the pauses.

It needs Python 3 and a dark terminal at least 100 columns wide.

## You should see

- Act 1: a `KernelContext` kernel, a `TileContext` GEMM, `cublasSgemv` and a `@Parallel` loop, captured into one CUDA graph.
- Act 2: FP16 GEMM bars for each tile shape, against a hand-tuned kernel and cuBLAS, each checked.
- A scoreboard ending in `PASSED -- every check holds`. A failed step shows a red `✘` and the path of its log.
