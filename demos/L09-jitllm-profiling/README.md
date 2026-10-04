# L09 · jitLLM, then profile it

The TornadoVM flags that L02 and L07 run on `VectorAddInt`, applied to a real workload.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL; the Nsight Systems part needs an NVIDIA GPU (Linux · CUDA) |
| GPU memory | as L06: 14GB budget by default, see [GPU memory](../L06-jitllm/README.md#gpu-memory) |
| Code | [beehive-lab/jitllm](https://github.com/beehive-lab/jitllm); build it as in [L06](../L06-jitllm/README.md) |
| Note | backup demo: its slide is hidden in the current deck |

## Run

```bash
cd "$JITLLM_ROOT"    # JITLLM_ROOT and M as in L06's Where things go
./jitllm --gpu --model "$M" --prompt "..." --print-kernel
./jitllm --gpu --model "$M" --prompt "..." --print-bytecodes
```

If you swap in an F16 Llama model on Metal, a source build of jitLLM refuses an FP16 key/value cache for it (`GPUL-CFG-002`); add `--fp32-kv-cache` to both commands. The JBang release in L06 does not need it.

All profiler options are grouped under "Debug and Profiling" in `./jitllm --help`.

## Profile it with Nsight Systems (Linux · CUDA)

This part needs an NVIDIA GPU and a TornadoVM build with the CUDA backend. Nsight Systems records CUDA activity, so on Metal, or on OpenCL even with an NVIDIA card, it finds no kernels; `run-nsys.sh` stops with a message if the backend is not CUDA. Nsight Systems ships with the CUDA toolkit.

The script needs the two folders from L06's [Where things go](../L06-jitllm/README.md#where-things-go):

- `JITLLM_ROOT`: the jitLLM clone you built in L06. It holds the `jitllm` launcher and `target/jitllm-*.jar`.
- `JITLLM_MODEL_DIR`: the folder you downloaded `gemma-4-E2B-it-Q4_0.gguf` into.

```bash
ls "$JITLLM_ROOT/jitllm" "$JITLLM_ROOT"/target/jitllm-*.jar "$JITLLM_MODEL_DIR/gemma-4-E2B-it-Q4_0.gguf"   # all three must exist

./run-nsys.sh                  # writes jitllm.nsys-rep: one kernel launch at a time
./run-nsys.sh --cuda-graphs    # writes jitllm-graphs.nsys-rep: each token replayed as one CUDA graph
nsys-ui jitllm.nsys-rep        # the timeline
```

Both commands assume you exported the two variables in this terminal (L06). Otherwise name them for the run, e.g. for a clone in `~/repositories/jitllm` and models in `/opt/models`: `JITLLM_ROOT=~/repositories/jitllm JITLLM_MODEL_DIR=/opt/models ./run-nsys.sh`. A last argument sets the number of tokens to generate (default 30). The jar in the clone decides the JDK: a `jdk21` jar from `tornadovm-dev.sh` needs JDK 21 and runs on that develop build; any other needs JDK 22+ and runs on the SDK in `TORNADOVM_HOME`. If something is missing, the script says which path or version it found.

The script runs jitLLM under `nsys profile --trace=cuda,nvtx,osrt` and prints the top GPU kernels. The launcher starts the JVM as a child process and nsys follows it, so by hand it is just `nsys profile -o jitllm ./jitllm --gpu --model "$M" --prompt "..."`, then `nsys stats --report cuda_gpu_kern_sum jitllm.nsys-rep`. With `--cuda-graphs` it adds jitLLM's `--cuda-graphs` and nsys's `--cuda-graph-trace=node`, which keeps every kernel inside the replayed graph visible. A 30-token run takes about 30 s.

### Narrating the demo

Record both reports before the session: nearly 17 s of each run has no GPU work, which is dead air on stage. You can still start `./run-nsys.sh` live while you introduce the demo, then open the recorded report. The numbers below are from Gemma 4 E2B Q4_0 on an RTX 5080 Laptop GPU with the 7.0.1 CUDA SDK; yours will differ, the shape will not.

1. **The command.** "Same jitLLM, same model. All I added is `nsys profile` in front. The launcher starts a JVM; nsys follows it and records every CUDA call and every kernel."
2. **The whole timeline: about 20 s, and the GPU idle for the first 17.** CUDA is up within a second, but the first kernel runs at about 18 s. jitLLM's `--verbose` splits the wait: 13.7 s to load the 3 GB model, then 2.9 s of JIT compilation, where Graal turns Java methods into 23 CUDA kernels. "It happens once, not per token: the pause before the first token in L06."
3. **Zoom into the start of the kernels: 1.6 GB of host-to-device copies.** TornadoVM copies the weights to the GPU on the first execution of each task graph and keeps them there. After that, each token copies about 58 KB.
4. **Zoom into one token.** About 980 kernel launches, 23 distinct kernels, the same block for every token. Read out the names: `fusedFFNGateUpGeGLUQ4_0DP4A` and `matrixVectorGenericQ4_0DP4A` are the quantised projections, `attentionDecodeGroupFP16` is attention, `rmsNorm…` the normalisation. "Each is a Java method; nsys shows the names from the Java code, not from CUDA C."
5. **The kernel summary.** Time spreads over many kernels. The largest, `matrixVectorGenericQ8Byte`, runs once per token: the step that produces the next-token scores, about 27% of GPU time.
6. **The gaps.** Zoom until the space between kernels shows. The GPU is busy for only about a quarter of each token; between kernels there are gaps of about 9 µs, the host launching the next one, some 980 times per token. "At this model size, launching kernels costs as much as running them."
7. **Close with CUDA graphs.** Open `jitllm-graphs.nsys-rep`. "jitLLM records each token as a CUDA graph and replays it with one launch. Same kernels, same Java."

| Under nsys, 30 tokens | default | `--cuda-graphs` |
|---|---|---|
| Time per token (median) | 19.2 ms | 8.1 ms |
| GPU busy within a token | 25% | 63% |
| Gap between kernels (median) | 8.6 µs | 0.2 µs |
| Tokens per second | 43.6 | 84.1 |

If asked: nsys costs some speed (43.6 tokens/s under nsys, 55.2 without, default mode), and the "45 tokens" jitLLM reports are every position it processed, the prompt plus the 30 generated tokens.

## What to look for

- Graal compiles every kernel once, on first use, and never again.
- Each token runs the same compiled kernels, plus the dispatch between them.
- The kernels: RMS norm, RoPE, attention and the quantised projections.
