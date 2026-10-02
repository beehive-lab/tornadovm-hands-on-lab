# L05 · TornadoViz

See the task graph, its transfers and every object's lifetime.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | under 100 MB; the TornadoVM default (4GB) is plenty |
| Code | the visualizer lives in [beehive-lab/TornadoViz](https://github.com/beehive-lab/TornadoViz); [`run.sh`](run.sh) in this repo produces the bytecode log |

## 1. Produce a bytecode log

```bash
./run.sh          # writes ./bytecodes next to this README
```

`--dumpBC DIR` sets `-Dtornado.print.bytecodes` and `-Dtornado.dump.bytecodes.dir` for you.

## 2. Build and run the visualizer

```bash
git clone https://github.com/beehive-lab/TornadoViz.git && cd TornadoViz
pip install -r requirements.txt
streamlit run tornado-visualizer-fixed.py
```

Load the dump in the browser.

## What to look for

- Task-graph dependencies and the data flowing between graphs.
- The memory timeline: allocations, host-to-device, device-to-host, deallocations.
- Try your own kernel with `FIRST_EXECUTION`, then `EVERY_EXECUTION`: the redundant transfers stand out.
