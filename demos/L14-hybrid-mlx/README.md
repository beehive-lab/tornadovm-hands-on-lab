# L14 · Hybrid API with Apple MLX

JIT → MLX `matmul` → JIT in one task graph, on shared device buffers, then the same SGEMM as a Java kernel and as `Mlx::matmul`, drawn for the big screen. The Metal twin of [L05](../L05-hybrid-cublas), which needs an NVIDIA GPU.

**Runs on:** macOS · Apple Silicon only (MLX is Apple's library) · **Needs:** [Setup once](../../README.md#setup-once) and TornadoVM 7.3.0 · **Code:** [`src/`](src) here

## Setup, once

`tornado-mlx`, the MLX library tasks, ships from TornadoVM 7.3.0, so this demo runs on its own SDK:

```bash
sdk install tornadovm 7.3.0-jdk22plus-metal      # answer n to making it the default
```

## Run

```bash
demos/L14-hybrid-mlx/run.sh
```

The script compiles `src/` into `demos/L14-hybrid-mlx/build`. It takes about 5 seconds plus [enter] between the two acts. `NO_PAUSE=1 demos/L14-hybrid-mlx/run.sh` skips the pause.

It needs Python 3 and a dark terminal at least 100 columns wide.

## You should see

- **Act 1:** the Java → MLX → Java task graph (`MlxSgemvHybrid`, 2048 × 2048), run 3 times. Each run shows every task's kernel time and `✔ correct`. `scale` and `bias` are Java, and `Mlx::matmul` is a method reference. The first MLX call takes about 25 ms, which is MLX's setup.
- **Act 2:** the same 2048³ SGEMM (`MlxGemmBenefit`) as a `@Parallel` Java kernel and as `Mlx::matmul`, shown as bars. On an M4 Pro: about 31 ms against 4.6 ms, 6.7×, or 550 against 3,700 GFLOP/s.
- A scoreboard ending in `PASSED -- every check holds`. A failed step shows a red `✘` and the path of its log.

## Compared with L05

| | L05 · cuBLAS | L14 · MLX |
|---|---|---|
| Library task | `.libraryTask("sgemv", CuBlas::cublasSgemv, OP_T, m, n, alpha, A, lda, x, 1, beta, y, 1)` | `.libraryTask("gemv", Mlx::matmul, A, x, y, m, n, 1)` |
| Layout | column-major, so a row-major Java matrix needs `CUBLAS_OP_T` | row-major, like the Java arrays |
| Act 2 | `withCUDAGraph()`: capture once, replay | no graph capture on Metal: Java kernel against the library for the same GEMM |

`Mlx.matmul(a, b, c, M, K, N)` computes `c = a · b` for `a` M × K and `b` K × N. A matrix-vector product is `N = 1`. The class has about 250 library tasks, from reductions and FFTs to convolutions. Run `javap -cp "$TORNADOVM_HOME/share/java/tornado/*" uk.ac.manchester.tornado.mlx.Mlx` with the 7.3.0 SDK active to list them.
