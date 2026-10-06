# L06 · jitLLM on your own GPU

An LLM inference engine written in Java. TornadoVM compiles its kernels for Metal, CUDA or OpenCL, whichever your SDK has.

**Runs on:** every backend · **GPU memory:** 14GB budget by default ([below](#gpu-memory)) · **Code:** [beehive-lab/jitllm](https://github.com/beehive-lab/jitllm) · **Model:** [Gemma 4 E2B instruct, Q4_0](https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF), 3GB

## Setup, once for L06–L10

```bash
demos/L06-jitllm/setup.sh
```

This clones jitLLM into `demos/L06-jitllm/jitllm` and builds it against your TornadoVM SDK, which takes under a minute. It then downloads the model into the clone, which takes as long as 3GB takes on your connection. Run it again at any time: it skips the steps already done.

## Run

To run the example prompt, "Explain GPU acceleration in one sentence.":

```bash
demos/L06-jitllm/jitllm.sh
```

To start the OpenAI-compatible server instead, which L10 uses, on port 8090:

```bash
demos/L06-jitllm/jitllm.sh serve
```

It first stops any jitLLM server left from an earlier run, which frees port 8090 and its GPU memory.

`jitllm.sh` runs the `./jitllm` launcher with `--gpu`, the memory budget and the model filled in.

## You should see

- A pause before the first token: TornadoVM is compiling the kernels, once.
- The answer, then `achieved tok/s: …`.
- With `serve`: the server starts, and `curl -s localhost:8090/v1/models` returns `"id":"gemma-4-E2B-it-Q4_0"`.

## GPU memory

jitLLM reserves its budget up front. Change it for one run with `JITLLM_GPU_MEMORY=8GB demos/L06-jitllm/jitllm.sh …`.

- **Smaller GPU:** lower the budget. If it is too small, jitLLM stops with `GPUL-MEM-001` and prints what the model needs; use that figure.
- **macOS:** the GPU can use only part of the unified memory, so a 16GB Mac needs a budget below 14GB.
- **Larger models:** 3–7B models need 15GB+; 8B+ models need 20GB+.

## Notes

- **Your own clone or model folder:** set `JITLLM_ROOT` (the clone) and `JITLLM_MODEL_DIR` (the folder with `gemma-4-E2B-it-Q4_0.gguf`). Every jitLLM script in L06–L10 reads both.
- **Several backends in one SDK:** run the launcher yourself with `--metal`, `--cuda` or `--opencl`; jitLLM otherwise picks the backend from the SDK.
- **Without building:** `jbang jitllm@beehive-lab -m demos/L06-jitllm/jitllm/gemma-4-E2B-it-Q4_0.gguf -p "…"` runs the released jitLLM ([JBang](https://www.jbang.dev/download/)).
