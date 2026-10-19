# L14 · Hybrid API with Apple MLX

Run L15's `FancyHybridMlx`, the class you walk through in IntelliJ: two Java kernels and `Mlx::matmul` in one task graph, with every task's kernel time. Then the same SGEMM as a Java kernel and as `Mlx::matmul`, where the library pulls far ahead. Drawn for the big screen. The Metal twin of [L05](../L05-hybrid-cublas), which needs an NVIDIA GPU.

**Runs on:** macOS · Apple Silicon only (MLX is Apple's library) · **Needs:** [Setup once](../../README.md#setup-once) and TornadoVM 7.3.1 · **Code:** [`src/`](src) here, and [L15](../L15-maven-starter) for act 1

## Setup, once

This demo runs L15's classes, so it runs on L15's SDK:

```bash
sdk install tornadovm 7.3.1-jdk22plus-metal      # answer n to making it the default
```

## Run

```bash
demos/L14-hybrid-mlx/run.sh
```

The script builds L15 with its Maven wrapper, and compiles `src/` into `demos/L14-hybrid-mlx/build`. It takes about 5 seconds plus [enter] between the two acts. `NO_PAUSE=1 demos/L14-hybrid-mlx/run.sh` skips the pauses.

It needs Python 3 and a dark terminal at least 105 columns wide.

## You should see

Figures from an M4 Pro. Times are kernel times from TornadoVM's profiler (`TASK_KERNEL_TIME`).

- **Act 1 · L15's FancyHybridMlx.** The `scale → Mlx::matmul → bias` task graph on a 2048 × 4096 layer, 5 executions, each with every task's kernel time and `✔ correct`. The two Java kernels take about 10 µs each, `Mlx::matmul` about 600 µs. The first execution includes MLX's setup, about 30 ms.
- **Act 2 · Where the library wins** (`MlxGemmBenefit`). The same 2048³ SGEMM as a `@Parallel` Java kernel and as `Mlx::matmul`: about 31 ms against 4.6 ms, 6.8×, or 550 against 3,800 GFLOP/s. This act times both by wall clock.
- A scoreboard ending in `PASSED -- every check holds`. A failed step shows a red `✘` and the path of its log.

## Reading the times

Act 1's times come from TornadoVM's profiler (`TASK_KERNEL_TIME`). For the Java kernels they are GPU timestamps (Metal's `GPUStartTime`/`GPUEndTime`). For `Mlx::matmul`, a library task, TornadoVM times the call on the host (`TornadoVMInterpreter`, the library launch): MLX's kernel plus its own command buffer and the wait for it, about 0.35 ms of the 600 µs. L05's first act reads the same timers: `scale` and `bias` from CUDA events, `sgemv` from the host. Act 2 times both versions by wall clock.

## Compared with L05

| | L05 · cuBLAS | L14 · MLX |
|---|---|---|
| Library task | `.libraryTask("sgemv", CuBlas::cublasSgemv, OP_T, k, m, alpha, W, k, x, 1, beta, y, 1)` | `.libraryTask("gemv", Mlx::matmul, W, x, y, m, k, 1)` |
| Layout | column-major, so a row-major Java matrix needs `CUBLAS_OP_T` | row-major, like the Java arrays |
| Graph replay | `withCUDAGraph()`: capture once, replay | none on Metal; `withCUDAGraph()` fails there in 7.3.1 |

`Mlx.matmul(a, b, c, M, K, N)` computes `c = a · b` for `a` M × K and `b` K × N. A matrix-vector product is `N = 1`. The class has about 250 library tasks, from reductions and FFTs to convolutions. Run `javap -cp "$TORNADOVM_HOME/share/java/tornado/*" uk.ac.manchester.tornado.mlx.Mlx` with the 7.3.1 SDK active to list them.
