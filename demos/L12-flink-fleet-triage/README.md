# L12 · Fleet telemetry triage

Eight million readings scored on the GPU, then a model in the same JVM writes the note.

**Runs on:** Linux · CUDA only (it shares L11's offload path) · **Code:** [mairooni/flink-accelerator-tornadovm](https://github.com/mairooni/flink-accelerator-tornadovm/tree/master), `demos/demo-llm.sh` · **Model:** [Qwen3-0.6B FP16](https://huggingface.co/gvij/qwen3-0.6b-gguf), 1.44 GiB

## Setup, once

The same three steps as [L11](../L11-flink-sql-gpu/README.md#setup-once-for-l11-and-l12). Skip this if you already ran them. `2-generate-data.sh` also downloads this demo's model and builds jitLLM and llama.cpp for it, which adds about fifteen minutes on its first run.

## Run

In every new shell, from `demos/L11-flink-sql-gpu/flink-accelerator-tornadovm/demos`:

```bash
source ./3-env.sh
./demo-llm.sh            # starts a Flink cluster, runs the job once, stops the cluster
```

## You should see

- The triage note the query produced: the machines that need inspection, with their anomalous-reading counts and scores.
- The counters: `engine jitllm`, the token counts and timings, and `model already resident`. The first run says `no -- this run loaded it` and spends about 7 s loading the model. Run it again and the model is already resident. `./demo-llm.sh --warm` loads the model before the run, so you see the resident timing first.
- Under "where the preprocessing ran": `Accelerated on this TaskManager (provider: tornadovm)`.

## Walk through the code

All in `flink-accelerator-tornadovm-examples`:

- `TelemetryTriage`: the SQL, with `TRIAGE()` called on a `LISTAGG` of the digest lines.
- `TriageFunction.eval`: a String in, a String out, an ordinary scalar UDF. The GPU work finishes before Flink calls it.
- `ResidentEngines`: Flink discards the job's classloader between jobs, so this holds the model loaded from `lib/` instead.

## Notes

- `./demo-llm.sh --cpu` is the comparison: CPU preprocessing and llama.cpp over HTTP.
- To run it straight after L11 on the same cluster, use `./demo-haversine.sh --print-kernel --keep-cluster`, then `./demo-llm.sh --keep-cluster`, then `./stop.sh`.
