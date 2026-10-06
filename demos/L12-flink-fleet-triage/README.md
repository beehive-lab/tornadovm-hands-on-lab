# L12 · Fleet telemetry triage

Eight million readings scored on the GPU, then a model in the same JVM writes the note.

**Runs on:** Linux · CUDA only (it shares L11's offload path) · **Code:** `flink-accelerator-tornadovm` · **Model:** Qwen3-0.6B FP16 (download URL to come)

**Not reproducible yet:** `flink-accelerator-tornadovm` is not public. Until it is, this page records what the slide runs.

## Run (as on the slide)

```bash
cd flink-accelerator-tornadovm
scripts/llm-bench-run.sh --gpu        # starts a cluster, runs once, stops it
```

## You should see

The counters at the end name the engine and say whether the model was already resident. The first run spends most of its time loading the model. Run it again and the model is already resident.

## Walk through the code

- `TelemetryTriage`: the SQL, with `TRIAGE()` called on a `LISTAGG` of the digest lines.
- `TriageFunction.eval`: a String in, a String out, an ordinary scalar UDF. The GPU work finishes before Flink calls it.
- `ResidentEngines`: Flink discards the job's classloader between jobs, so this holds the model loaded from `lib/` instead.
