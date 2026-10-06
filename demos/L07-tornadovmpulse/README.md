# L07 · TornadoVMPulse

A dashboard for the TornadoVM profiler's output.

**Runs on:** every backend; the power panel needs NVIDIA · **Needs:** [Setup once](../../README.md#setup-once) · **Code:** [beehive-lab/TornadoVMPulse](https://github.com/beehive-lab/TornadoVMPulse)

## Run

**1. Profile a workload** with one of the two scripts:

```bash
demos/L07-tornadovmpulse/run.sh           # VectorAddInt → profile.json
demos/L07-tornadovmpulse/run-jitllm.sh    # jitLLM       → profile-jitllm.json   (needs L06's setup.sh)
```

**2. Start TornadoVMPulse**, then upload that file in the browser. Both files are in `demos/L07-tornadovmpulse/`.

```bash
demos/L07-tornadovmpulse/tornadovm-pulse.sh
```

The first start clones TornadoVMPulse and installs its requirements; later starts skip that.

## You should see

- Step 1 ends with `Wrote …/profile.json` (or `…/profile-jitllm.json`).
- Step 2 prints `Local URL: http://localhost:8501`; open it if the browser does not open by itself.
- The sunburst chart: on a first run, kernel time is a sliver of the total.
- Copy-in and copy-out time and count per task graph.
- Power, from NVML, on NVIDIA only. On other GPUs that panel stays empty.

## Notes

- **`run-jitllm.sh` file size:** the profile grows with every token. By default it generates 30 tokens, about 16 MB; `run-jitllm.sh 5` gives about 7 MB. These figures are from an RTX 5080 Laptop GPU. The file isn't in the repository because of its size, and because it depends on your GPU.
- **Logs:** jitLLM's console output goes to `demos/L07-tornadovmpulse/jitllm.log`.
- **Dashboard environment:** it runs in its own Python environment, `TornadoVMPulse/.venv`. Extra arguments go to streamlit, for example `--server.port 8502`.
