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

## 2. Build and run the dashboard

```bash
git clone https://github.com/beehive-lab/TornadoVMPulse.git && cd TornadoVMPulse
pip install -r requirements.txt
streamlit run src/app.py
```

Upload `profile.json` in the browser. Raw JSON or log files are converted to CSV automatically; the time unit (ns, ms, s) is in the sidebar.

## What to look for

- The sunburst chart: on a first run, kernel time is a sliver of the total.
- Copy-in and copy-out: time and count per task graph.
- Power comes from NVML on NVIDIA; on the Mac that panel stays empty.
