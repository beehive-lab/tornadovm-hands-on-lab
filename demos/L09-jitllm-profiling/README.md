# L09 · jitLLM, then profile it

The flags L02 and L07 ran on `VectorAddInt`, now on a real workload, then the whole run under Nsight Systems. Backup demo: its slide is hidden in the current deck.

**Runs on:** every backend; part 2 needs an NVIDIA GPU with the CUDA backend · **Needs:** L06's setup

## 1. The kernels and the bytecodes

These call the jitLLM launcher directly, in the clone L06's `setup.sh` made, where the model also is:

```bash
cd demos/L06-jitllm/jitllm
export JITLLM_ROOT=$PWD     # the launcher reads it
./jitllm --gpu --model gemma-4-E2B-it-Q4_0.gguf --max-new-tokens 5 --prompt "Explain GPU acceleration in one sentence." --print-kernel
./jitllm --gpu --model gemma-4-E2B-it-Q4_0.gguf --max-new-tokens 2 --prompt "Explain GPU acceleration in one sentence." --print-bytecodes
cd -                        # back to the root of this repository, for part 2
```

You should see the generated kernels: RMS norm, RoPE, attention and the quantised projections. Then the bytecodes: the same compiled kernels, launched for every token.

## 2. Nsight Systems (Linux · CUDA)

```bash
demos/L09-jitllm-profiling/run-nsys.sh                  # → jitllm.nsys-rep: one kernel launch at a time
demos/L09-jitllm-profiling/run-nsys.sh --cuda-graphs    # → jitllm-graphs.nsys-rep: each token as one CUDA graph
nsys-ui demos/L09-jitllm-profiling/jitllm.nsys-rep      # the timeline
```

Each run takes about 30 seconds and prints the top GPU kernels by time. `nsys` ships with the CUDA toolkit. The script stops with a message if the backend is not CUDA: Nsight Systems records CUDA activity, so with Metal or OpenCL it finds nothing.

You should see a long stretch of the timeline with no GPU work while the model loads and the kernels compile, once. Then the same block of kernels runs for every token. With `--cuda-graphs`, the gaps between kernels close.

## Notes

- The jitLLM options for profiling are under "Debug and Profiling" in `./jitllm --help`, in the jitLLM clone.
- By hand, part 2 is `nsys profile -o jitllm ./jitllm --gpu --model gemma-4-E2B-it-Q4_0.gguf --prompt "…"` in the jitLLM clone, then `nsys stats --report cuda_gpu_kern_sum jitllm.nsys-rep`. `run-nsys.sh --cuda-graphs` adds jitLLM's `--cuda-graphs` and nsys's `--cuda-graph-trace=node`, which keeps the kernels inside each graph visible.
- `run-nsys.sh 10` generates 10 tokens instead of 30.
