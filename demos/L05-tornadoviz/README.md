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

With jitLLM as the workload instead of `VectorAddInt`, run `run-jitllm.sh`. The script needs the two folders from L08's [Where things go](../L08-jitllm/README.md#where-things-go):

- `JITLLM_ROOT`: the jitLLM clone you built in L08. It holds the `jitllm` launcher and `target/jitllm-*.jar`.
- `JITLLM_MODEL_DIR`: the folder you downloaded `gemma-4-E2B-it-Q4_0.gguf` into.

```bash
ls "$JITLLM_ROOT/jitllm" "$JITLLM_ROOT"/target/jitllm-*.jar "$JITLLM_MODEL_DIR/gemma-4-E2B-it-Q4_0.gguf"   # all three must exist

./run-jitllm.sh    # if you exported both in this terminal (L08); writes bytecodes-jitllm/
JITLLM_ROOT=~/repositories/jitllm JITLLM_MODEL_DIR=/opt/models ./run-jitllm.sh    # or name them for this run only, e.g. a clone in ~/repositories/jitllm and models in /opt/models
```

An optional argument sets the number of tokens to generate (default 10). The jar in the clone decides the JDK: a `jdk21` jar from `tornadovm-dev.sh` needs JDK 21 and runs on that develop build; any other needs JDK 22+ and runs on the SDK in `TORNADOVM_HOME`. If something is missing, the script says which path or version it found.

The output grows with every generated token, so keep the run short. jitLLM's console output goes to `jitllm.log`.

## 2. Build and run the visualizer

```bash
./tornadoviz.sh          # extra arguments go to streamlit, e.g. --server.port 8502
```

It prints each command before running it, and skips the steps already done: it clones TornadoViz next to this README, installs its requirements in `TornadoViz/.venv` (a system-wide `pip install` is refused on Pythons marked externally managed), and starts the visualizer. By hand, the steps are:

```bash
git clone https://github.com/beehive-lab/TornadoViz.git && cd TornadoViz
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/streamlit run tornado-visualizer-fixed.py
```

Load the dump in the browser: `bytecodes/` from `run.sh`, or `bytecodes-jitllm/tornadovm_bytecodes.log` from `run-jitllm.sh`.

## What to look for

- Task-graph dependencies and the data flowing between graphs.
- The memory timeline: allocations, host-to-device, device-to-host, deallocations.
- Try your own kernel with `FIRST_EXECUTION`, then `EVERY_EXECUTION`: the redundant transfers stand out.
