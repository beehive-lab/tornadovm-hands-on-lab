# L11 · An SQL operator on the GPU

Ordinary Flink SQL, one config key, and the CUDA it compiled to.

**Runs on:** Linux · CUDA only (RAPIDS cuDF runs on Linux with NVIDIA GPUs) · **Code:** [mairooni/flink-accelerator-tornadovm](https://github.com/mairooni/flink-accelerator-tornadovm/tree/master), `demos/demo-haversine.sh`

## Setup, once for L11 and L12

```bash
git clone https://github.com/mairooni/flink-accelerator-tornadovm.git demos/L11-flink-sql-gpu/flink-accelerator-tornadovm
cd demos/L11-flink-sql-gpu/flink-accelerator-tornadovm/demos
./1-fetch.sh             # clones and builds TornadoVM develop, Flink, jitLLM and llama.cpp: 40-70 minutes the first time
./2-generate-data.sh     # the log corpora (about 2.4 GB) and L12's model (1.44 GiB), then L12's setup
```

These scripts need an NVIDIA GPU, a CUDA toolkit, **JDK 21** (`sdk install java 21.0.2-open`, which they find on their own), Maven, CMake, Python 3, git and a C++20 compiler. They check for each one, and they skip the steps already done, so a failed run can be fixed and run again. The builds and the data go to `~/flink-tornadovm-demos`, outside this repository.

## Run

In every new shell, from `demos/L11-flink-sql-gpu/flink-accelerator-tornadovm/demos`:

```bash
source ./3-env.sh                    # sets the paths and lists anything missing
./demo-haversine.sh --print-kernel   # starts a Flink cluster, runs the query, stops the cluster
```

## You should see

- `3-env.sh` prints `ready.` after the list of paths. Any line marked `MISSING` needs fixing first.
- The result for 8,000,000 points: the nearest and farthest depot distances in km.
- Under "where it ran": `Accelerated on this TaskManager (provider: tornadovm)`. If instead it says no accelerator decision was logged, the query ran on the CPU.
- Under "what TornadoVM printed": the path of the TaskManager's `.out` file, which holds the generated CUDA (`__global__`). That kernel exists nowhere in the repository: it was compiled from the SQL during this run.

## Walk through the code

Open these in IntelliJ, in this order:

1. `HaversineSQLExample`, in `flink-accelerator-tornadovm-examples`: the SQL and the config switch. `NOT NULL` in the DDL is the only thing written for the GPU.
2. `GpuOffloadProcessor`, in the Flink fork (`~/flink-tornadovm-demos/flink`, under `flink-table-planner`): where Flink accepts or declines the offload, with a reason string.
3. `AccelKernelGenerator`, in `flink-accelerator-tornadovm`: the expression tree becoming a `@Parallel` Java method.

## Notes

- `./demo-haversine.sh --cpu` runs the same query with the accelerator off. `--keep-cluster` leaves the cluster up so the job stays visible at <http://localhost:8081>; `./stop.sh` stops it.
- The repository's own guide is `demos/README.md` in the clone.
