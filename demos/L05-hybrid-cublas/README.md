# L05 · Hybrid API with cuBLAS

JIT → cuBLAS `sgemv` → JIT in one task graph, on shared device buffers.

| | |
|---|---|
| Platforms | Linux · CUDA only (cuBLAS is an NVIDIA library) |
| GPU memory | a few MB at the default size `8 8 5` |
| Code | [beehive-lab/tornadovm-devoxx2026-cuda-demos](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos), [`demos/04-cublas-hybrid`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/tree/main/demos/04-cublas-hybrid) (class `CuBlasSgemvHybrid`), and [`devoxx/fancyHybrid.sh`](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos/blob/main/devoxx/fancyHybrid.sh) |

## Build

```bash
git clone https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos.git
cd tornadovm-devoxx2026-cuda-demos
source scripts/setup-env.sh          # JAVA_HOME, TORNADOVM_HOME, PATH, argfile
bash scripts/run-all-demos.sh        # optional: every demo, both run paths
cd demos/04-cublas-hybrid
javac -cp "$TORNADOVM_HOME/share/java/tornado/*" -d . CuBlasSgemvHybrid.java
```

## Run

```bash
tornado --enableProfiler console --printBytecodes --classpath . CuBlasSgemvHybrid 8 8 5
```

Arguments are `<m> <n> <iterations>` (defaults `8 8 5`). The plain-`java` form is `java @$TORNADOVM_HOME/tornado-argfile -cp . CuBlasSgemvHybrid 8 8 5`.

## What to look for

- `scale` and `bias` are Java; `sgemv` is `CuBlas::cublasSgemv`, a method reference into a Java module.
- The profiler: all three stages report the same CUDA device. Every iteration prints `correct`.
- The bytecodes: one graph capture, then replays with the same graph id.

## The fancy version: `fancyHybrid.sh`

The `devoxx` folder of the CUDA demos repo has the same program drawn for the big screen. `fancyHybrid.sh` runs two acts, each checked against the CPU: this demo's Java → cuBLAS → Java task graph with kernel time per task, then demo 07's CUDA-graph replay, plain against `withCUDAGraph()`, as bars. It takes about 10 seconds.

```bash
git clone https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos.git
cd tornadovm-devoxx2026-cuda-demos/devoxx
bash fancyHybrid.sh          # NO_PAUSE=1 bash fancyHybrid.sh to skip the [enter] between acts
```

The script sources the repo's `scripts/setup-env.sh` and compiles the demos it needs. It renders with Python 3 (standard library only) and wants a dark terminal at least 100 columns wide with Unicode block characters. It ends with a scoreboard that says `PASSED` only if every check held. If a step fails, its spinner turns into a red `✘` with the path of its log.

The CUDA demos repo selects its SDK in `env/versions.env` (`TORNADO_SDK_PROFILE`), which defaults to **7.0.0**, while this lab uses 7.1.0. Check which one `setup-env.sh` picked before running the demo or the script.
