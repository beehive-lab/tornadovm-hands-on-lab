# L12 · Fleet telemetry triage

Eight million readings scored on the GPU, then a model in the same JVM writes the note.

| | |
|---|---|
| Platforms | Linux · CUDA only (shares L11's offload path) |
| GPU memory | TODO: record (8M readings plus Qwen3-0.6B FP16 resident in the same JVM) |
| Code | `flink-accelerator-tornadovm` (TODO: public URL) |
| Model | Qwen3-0.6B FP16 (TODO: download URL) |

**Not reproducible yet.** The code lives in `flink-accelerator-tornadovm`, which is not public: `github.com/beehive-lab/flink-accelerator-tornadovm` returns 404. Until it is published, this README records what the slide runs.

## Run (as on the slide)

```bash
cd flink-accelerator-tornadovm
scripts/llm-bench-run.sh --gpu        # starts a cluster, runs once, stops it
```

## What to look for

- `TelemetryTriage`: the SQL, with `TRIAGE()` called on a `LISTAGG` of the digest lines.
- `TriageFunction.eval`: a String in, a String out, an ordinary scalar UDF. The GPU work finishes before it is called.
- Flink throws the job's classloader away between jobs, so `ResidentEngines` holds the model from `lib/` instead.
- The counters at the end name the engine and say whether the model was already resident.

Most of the first run is loading the model. Run it again and the model is already resident, which is the point of `ResidentEngines`.
