# L08 · TornadoViz

See the task graph, its transfers and every object's lifetime.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once) · **Code:** [beehive-lab/TornadoViz](https://github.com/beehive-lab/TornadoViz)

## Run

**1. Dump a workload's bytecodes** with one of the two scripts:

```bash
demos/L08-tornadoviz/run.sh           # VectorAddInt → bytecodes/tornadovm_bytecodes.log
demos/L08-tornadoviz/run-jitllm.sh    # jitLLM       → bytecodes-jitllm/tornadovm_bytecodes.log   (needs L06's setup.sh)
```

**2. Start TornadoViz**, then load that `tornadovm_bytecodes.log` in the browser. Both folders are in `demos/L08-tornadoviz/`.

```bash
demos/L08-tornadoviz/tornadoviz.sh
```

The first start clones TornadoViz and installs its requirements; later starts skip that.

## You should see

- Step 1 ends with `Wrote …/bytecodes` (or `…/bytecodes-jitllm`).
- Step 2 prints `Local URL: http://localhost:8501`; open it if the browser does not open by itself.
- The task-graph dependencies and the data flowing between graphs.
- The memory timeline: allocations, host-to-device, device-to-host, deallocations.

## Notes

- **`run-jitllm.sh` file size:** the log grows with every token. By default it generates 10 tokens, about 11 MB; `run-jitllm.sh 5` gives about 8 MB. These figures are from an RTX 5080 Laptop GPU. The file isn't in the repository because of its size, and because it depends on your GPU.
- **Logs:** jitLLM's console output goes to `demos/L08-tornadoviz/jitllm.log`.
- **`--dumpBC`:** `run.sh` uses `--dumpBC DIR`, which sets `-Dtornado.print.bytecodes` and `-Dtornado.dump.bytecodes.dir` for you.
- **Your own kernel:** compare `FIRST_EXECUTION` against `EVERY_EXECUTION`; the redundant transfers stand out.
- **Visualizer environment:** it runs in its own Python environment, `TornadoViz/.venv`. Extra arguments go to streamlit, for example `--server.port 8502`.
