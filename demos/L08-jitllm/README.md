# L08 · jitLLM on your own GPU

An LLM inference engine in Java; TornadoVM compiles its kernels for Metal, OpenCL or CUDA, picked from your SDK.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | 14GB budget by default; more for larger models, less is possible on smaller GPUs (see below) |
| Code | [beehive-lab/jitllm](https://github.com/beehive-lab/jitllm) |
| Model | `beehive-llama-3.2-1b-instruct-fp16.gguf` (TODO: add its download URL) |

## Run without building (released SDK + JBang)

```bash
curl -Ls https://sh.jbang.dev | bash -s - app setup      # once
M=beehive-llama-3.2-1b-instruct-fp16.gguf
jbang jitllm@beehive-lab -m $M -p "Explain GPU acceleration in one sentence."
```

Check `jbang jitllm@beehive-lab --help` for the memory option on this path; the flags below are for the `./jitllm` launcher.

## Build from source

Building jitLLM from a clone needs TornadoVM **develop** artifacts, which neither the 7.0.1 SDK nor Maven Central provides. The repo's helper prepares them for your platform:

```bash
git clone https://github.com/beehive-lab/jitllm.git && cd jitllm
scripts/tornadovm-dev.sh setup --backend metal  --jdk 21    # macOS
scripts/tornadovm-dev.sh setup --backend cuda   --jdk 21    # Linux, NVIDIA
scripts/tornadovm-dev.sh setup --backend opencl --jdk 21    # Linux, Intel or AMD
scripts/tornadovm-dev.sh build clean install -DskipTests
eval "$(scripts/tornadovm-dev.sh env)"                       # TORNADOVM_HOME + PATH for this shell
```

## Run

```bash
./jitllm --gpu --verbose --gpu-memory 14GB --model $M \
    --prompt "Explain the benefits of GPU acceleration."
./jitllm serve -m $M --gpu --gpu-memory 14GB --port 8090     # OpenAI-compatible, used by L10
```

The backend is detected from the SDK. On an SDK with several backends, force one with `--metal`, `--cuda` or `--opencl`.

## GPU memory

jitLLM reserves a device budget up front. The lab's default is `JITLLM_GPU_MEMORY` in [`env/versions.env`](../../env/versions.env); the numbers below are jitLLM's own recommendations.

| Model size | Budget | Flag |
|---|---|---|
| 1B (this lab) | 14GB (default) | none |
| 3–7B | 15GB+ | `--gpu-memory 15GB` |
| 8B+ | 20GB+ | `--gpu-memory 20GB` |

- **Smaller GPU than the budget:** lower it, for example `--gpu-memory 8GB`. If the budget is too small, jitLLM stops with `GPUL-MEM-001`, states how much the model needs, and prints a per-component memory plan; set the budget to that figure.
- **macOS:** memory is unified, and macOS lets the GPU use only part of it. On a 16GB Mac a 14GB budget may not fit, so lower it and stay with the 1B model.
- **Still out of memory:** use a Q4_0 model instead of Q8_0, shorten the context, or close other GPU applications.

## What to look for

- The pause before the first token is one-time JIT compilation, not the model.
- `--verbose` prints the device, the TornadoVM version and the GPU allocation budget before generating.
- `serve` exposes `/v1/chat/completions`, which DevoxxGenie uses in L10.

If the build fights you on Linux, the fallback is the `beehivelab/gpullama3.java-nvidia-openjdk-opencl` Docker image.
