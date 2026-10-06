# L11 · An SQL operator on the GPU

Ordinary Flink SQL, one config key, and the CUDA it compiled to.

**Runs on:** Linux · CUDA only (RAPIDS cuDF runs on Linux with NVIDIA GPUs) · **Code:** `flink-accelerator-tornadovm`

**Not reproducible yet:** `flink-accelerator-tornadovm` is not public. Until it is, this page records what the slide runs.

## Run (as on the slide)

```bash
cd flink-accelerator-tornadovm
export TORNADO_SDK=…  RAPIDS_HOME=…
scripts/run-sql-demos.sh haversine --printKernel
```

TornadoVM PR #773 renamed `TORNADO_SDK` to `TORNADOVM_HOME`; check which one the scripts expect.

## You should see

`--printKernel` prints CUDA that does not exist anywhere in the repository: it was compiled from the SQL during this run. Without a GPU the run still succeeds, on the CPU path.

## Walk through the code

Open these in IntelliJ, in this order:

1. `HaversineSQLExample`: the SQL and the config switch. `NOT NULL` in the DDL is the only thing written for the GPU.
2. `GpuOffloadProcessor`: where Flink accepts or declines the offload, with a reason string.
3. `AccelKernelGenerator`: the expression tree becoming a `@Parallel` Java method.
