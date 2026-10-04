# L07 · TornadoVMPulse

A dashboard for the TornadoVM profiler's output.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL (the power panel needs NVIDIA) |
| GPU memory | under 100 MB; the TornadoVM default (4GB) is plenty |
| Code | the dashboard lives in [beehive-lab/TornadoVMPulse](https://github.com/beehive-lab/TornadoVMPulse); [`run.sh`](run.sh) in this repo produces the profile |

## 1. Produce a profile

```bash
./run.sh          # writes profile.json next to this README
```

With jitLLM as the workload instead of `VectorAddInt`, run `run-jitllm.sh`. The script needs the two folders from L06's [Where things go](../L06-jitllm/README.md#where-things-go):

- `JITLLM_ROOT`: the jitLLM clone you built in L06. It holds the `jitllm` launcher and `target/jitllm-*.jar`.
- `JITLLM_MODEL_DIR`: the folder you downloaded `gemma-4-E2B-it-Q4_0.gguf` into.

```bash
ls "$JITLLM_ROOT/jitllm" "$JITLLM_ROOT"/target/jitllm-*.jar "$JITLLM_MODEL_DIR/gemma-4-E2B-it-Q4_0.gguf"   # all three must exist

./run-jitllm.sh    # if you exported both in this terminal (L06); writes profile-jitllm.json
JITLLM_ROOT=~/repositories/jitllm JITLLM_MODEL_DIR=/opt/models ./run-jitllm.sh    # or name them for this run only, e.g. a clone in ~/repositories/jitllm and models in /opt/models
```

An optional argument sets the number of tokens to generate (default 30). The jar in the clone decides the JDK: a `jdk21` jar from `tornadovm-dev.sh` needs JDK 21 and runs on that develop build; any other needs JDK 22+ and runs on the SDK in `TORNADOVM_HOME`. If something is missing, the script says which path or version it found.

The output grows with every generated token, so keep the run short. jitLLM's console output goes to `jitllm.log`.

## 2. Build and run the dashboard

```bash
./tornadovm-pulse.sh          # extra arguments go to streamlit, e.g. --server.port 8502
```

It prints each command before running it, and skips the steps already done: it clones TornadoVMPulse next to this README, installs its requirements in `TornadoVMPulse/.venv` (a system-wide `pip install` is refused on Pythons marked externally managed), and starts the dashboard. By hand, the steps are:

```bash
git clone https://github.com/beehive-lab/TornadoVMPulse.git && cd TornadoVMPulse
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/streamlit run src/app.py
```

Upload `profile.json` in the browser. Raw JSON or log files are converted to CSV automatically; the time unit (ns, ms, s) is in the sidebar.

## What to look for

- The sunburst chart: on a first run, kernel time is a sliver of the total.
- Copy-in and copy-out: time and count per task graph.
- Power comes from NVML on NVIDIA; on the Mac that panel stays empty.
