# L09 · jitLLM, then profile it

The TornadoVM flags from the MacBook part (L02, L04), applied to a real workload.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | as L08: 14GB budget by default, see [GPU memory](../L08-jitllm/README.md#gpu-memory) |
| Code | [beehive-lab/jitllm](https://github.com/beehive-lab/jitllm); build it as in [L08](../L08-jitllm/README.md) |
| Note | backup demo: its slide is hidden in the current deck |

## Run

```bash
M=gemma-4-E2B-it-Q4_0.gguf
./jitllm --gpu --model $M --prompt "..." --print-kernel
./jitllm --gpu --model $M --prompt "..." --print-bytecodes
```

If you swap in an F16 Llama model on Metal, a source build of jitLLM refuses an FP16 key/value cache for it (`GPUL-CFG-002`); add `--fp32-kv-cache` to both commands. The JBang release in L08 does not need it.

All profiler options are grouped under "Debug and Profiling" in `./jitllm --help`.

## What to look for

- Graal compiles every kernel once, on first use, and never again.
- Each token runs the same compiled kernels, plus the dispatch between them.
- The kernels: RMS norm, RoPE, attention and the quantised projections.
