# L08 · jitLLM on your own GPU

An LLM inference engine in Java; TornadoVM compiles its kernels for Metal, OpenCL or CUDA, picked from your SDK.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | 14GB budget by default; more for larger models, less is possible on smaller GPUs (see below) |
| Code | [beehive-lab/jitllm](https://github.com/beehive-lab/jitllm) |
| Model | [`gemma-4-E2B-it-Q4_0.gguf`](https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_0.gguf) (Gemma 4 E2B instruct, Q4_0, 3GB) |

## Where things go

jitLLM needs two folders: one for the jitLLM clone, one for the model. Choose them once; L08–L10 use them, and so do the jitLLM scripts in L04, L05 and L09 (`run-jitllm.sh`, `run-nsys.sh`), which read them from `JITLLM_ROOT` and `JITLLM_MODEL_DIR`:

```bash
export JITLLM_ROOT=$HOME/jitllm                       # the jitLLM clone; it is built and run from here
export JITLLM_MODEL_DIR=$HOME/models                  # the folder the model is downloaded into
export M=$JITLLM_MODEL_DIR/gemma-4-E2B-it-Q4_0.gguf   # the model file itself
```

Any folders work. If you already have a clone in `~/repositories/jitllm`, or models in `/opt/models`, point the variables there instead. `export` keeps them for the rest of this terminal; in a new terminal, run the three lines again.

## Download the model

```bash
mkdir -p "$JITLLM_MODEL_DIR"
curl -L -o "$M" https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_0.gguf
ls -lh "$M"                                           # about 2.9GB
```

## Run without building (released SDK + JBang)

```bash
curl -Ls https://sh.jbang.dev | bash -s - app setup      # once
jbang jitllm@beehive-lab -m "$M" -p "Explain GPU acceleration in one sentence."
```

Check `jbang jitllm@beehive-lab --help` for the memory option on this path; the flags below are for the `./jitllm` launcher.

## Build from source

Building jitLLM from a clone needs TornadoVM **develop** artifacts, which neither the 7.0.1 SDK nor Maven Central provides. The repo's helper prepares them for your platform. It builds for JDK 21 and stops with `the java on JAVA_HOME/PATH is 25` while the lab's JDK 25 is selected, so switch this shell to JDK 21 first and keep it for the build and every `./jitllm` run:

```bash
sdk install java 21.0.2-open && sdk use java 21.0.2-open    # this shell only
git clone https://github.com/beehive-lab/jitllm.git "$JITLLM_ROOT" && cd "$JITLLM_ROOT"
scripts/tornadovm-dev.sh setup --backend metal  --jdk 21    # macOS
scripts/tornadovm-dev.sh setup --backend cuda   --jdk 21    # Linux, NVIDIA
scripts/tornadovm-dev.sh setup --backend opencl --jdk 21    # Linux, Intel or AMD
scripts/tornadovm-dev.sh build clean install -DskipTests
eval "$(scripts/tornadovm-dev.sh env)"                       # TORNADOVM_HOME + PATH for this shell
```

## Run

```bash
cd "$JITLLM_ROOT"
./jitllm --gpu --verbose --gpu-memory 14GB --model "$M" \
    --prompt "Explain the benefits of GPU acceleration."
./jitllm serve -m "$M" --gpu --gpu-memory 14GB --port 8090   # OpenAI-compatible, used by L10
```

The backend is detected from the SDK. On an SDK with several backends, force one with `--metal`, `--cuda` or `--opencl`.

## GPU memory

jitLLM reserves a device budget up front. The lab's default is `JITLLM_GPU_MEMORY` in [`env/versions.env`](../../env/versions.env); the numbers below are jitLLM's own recommendations.

| Model size | Budget | Flag |
|---|---|---|
| Gemma 4 E2B Q4_0 (this lab) | 14GB (default) | none |
| 3–7B | 15GB+ | `--gpu-memory 15GB` |
| 8B+ | 20GB+ | `--gpu-memory 20GB` |

- **Smaller GPU than the budget:** lower it, for example `--gpu-memory 8GB`. If the budget is too small, jitLLM stops with `GPUL-MEM-001`, states how much the model needs, and prints a per-component memory plan; set the budget to that figure.
- **macOS:** memory is unified, and macOS lets the GPU use only part of it. On a 16GB Mac a 14GB budget may not fit, so lower it and stay with the lab's model.
- **Still out of memory:** use a Q4_0 model instead of Q8_0, shorten the context, or close other GPU applications.

## What to look for

- The pause before the first token is one-time JIT compilation, not the model.
- `--verbose` prints the device, the TornadoVM version and the GPU allocation budget before generating.
- `serve` exposes `/v1/chat/completions`, which DevoxxGenie uses in L10.

If the build fights you on Linux, the fallback is the `beehivelab/gpullama3.java-nvidia-openjdk-opencl` Docker image.
