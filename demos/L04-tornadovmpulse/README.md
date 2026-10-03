# L04 · TornadoVMPulse

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

With jitLLM as the workload instead of `VectorAddInt`, using its source build from [L08](../L08-jitllm/README.md) (JDK 21):

```bash
JITLLM_ROOT=~/jitllm JITLLM_MODEL_DIR=~/models ./run-jitllm.sh    # writes profile-jitllm.json; optional arg: max new tokens (default 30)
```

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
