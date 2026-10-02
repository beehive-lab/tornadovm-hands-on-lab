# L11 · An SQL operator on the GPU

Ordinary Flink SQL, one config key, and the CUDA it compiled to.

| | |
|---|---|
| Platforms | Linux · CUDA only (RAPIDS cuDF runs on Linux with NVIDIA GPUs) |
| GPU memory | TODO: record (8M rows of Parquet) |
| Code | `flink-accelerator-tornadovm` (TODO: public URL) |

**Not reproducible yet.** The code lives in `flink-accelerator-tornadovm`, which is not public: `github.com/beehive-lab/flink-accelerator-tornadovm` returns 404. Until it is published, this README records what the slide runs.

## Run (as on the slide)

```bash
cd flink-accelerator-tornadovm
export TORNADO_SDK=…  RAPIDS_HOME=…
scripts/run-sql-demos.sh haversine --printKernel
```

`TORNADO_SDK` was renamed `TORNADOVM_HOME` in TornadoVM PR #773; check which one the scripts expect.

## What to look for

Open these files in IntelliJ, in this order:

1. `HaversineSQLExample`: the SQL and the config switch. `NOT NULL` in the DDL is the only thing written for the GPU.
2. `GpuOffloadProcessor`: where Flink accepts or declines the offload, with a reason string.
3. `AccelKernelGenerator`: the expression tree becoming a `@Parallel` Java method.

`--printKernel` prints CUDA that exists nowhere in the repository: it was compiled from the SQL in this run. Without a GPU the run still succeeds on the CPU path.
