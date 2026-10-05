# TornadoVM Hands-On Lab

Every demo from *From Install to Insight: A Hands-On GPU Lab for Java Developers*, the TornadoVM hands-on lab for 2026, reproducible on macOS and Linux. Each demo has an identifier, `L01`–`L13`, used in folder names, in the deck and in conversation. The identifiers follow the order the demos run in the lab, which is not always the order of the slides: TornadoVMPulse (L07) and TornadoViz (L08) run after jitLLM (L06), so they can profile it.

Demos whose code already lives in another repository get a README here with the base build and run steps. Demos that only use the TornadoVM SDK's built-in examples get a `run.sh`, which detects the installed backend and runs the variant that fits it.

## Quick start

```bash
sdk install java 25.0.2-open
sdk install tornadovm 7.1.0-jdk22plus-metal      # macOS, Apple Silicon
sdk install tornadovm 7.1.0-jdk22plus-cuda       # Linux, NVIDIA
sdk install tornadovm 7.1.0-jdk22plus-opencl     # Linux, Intel or AMD

scripts/check-env.sh       # SDK, backends, GPUs and their memory, demos that apply here
scripts/run-all.sh         # every scripted demo, with PASS / SKIP / FAIL per demo
```

All versions, repositories, branches and memory budgets are pinned in [`env/versions.env`](env/versions.env).

## Demos

✓ runs as shown · ◐ runs with a platform variant or with a part skipped · ✗ not available on that platform. Slide numbers refer to the deck of 2 October 2026; the rows follow the lab order.

| ID | Demo | Slide | macOS · Metal | Linux · CUDA | Linux · OpenCL | GPU memory | Code |
|---|---|---|---|---|---|---|---|
| [L01](demos/L01-sdkman) | SDKMAN! | 42 | ✓ | ✓ | ✓ | < 100 MB | this repo |
| [L02](demos/L02-metal-look-inside) | Run on Metal, then look inside | 46 (hidden) | ✓ | ✓ | ✓ | < 100 MB | this repo |
| [L03](demos/L03-tornadoinsight) | Debug with TornadoInsight | 47 | ✓ | ✓ | ✓ | small | [tornado-insight](https://github.com/beehive-lab/tornado-insight) |
| [L04](demos/L04-cuda-tilecontext) | GEMM: CUDA TileContext, Metal simdgroup | 88 | ◐ simdgroup GEMM | ✓ | ◐ portable GEMM | < 100 MB | this repo + [cuda-demos](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos) `devoxx/fancyTile.sh` (Linux · NVIDIA) |
| [L05](demos/L05-hybrid-cublas) | Hybrid API with cuBLAS | 93 | ✗ | ✓ | ✗ | a few MB | [cuda-demos](https://github.com/beehive-lab/tornadovm-devoxx2026-cuda-demos) demo 04, `devoxx/fancyHybrid.sh` |
| [L06](demos/L06-jitllm) | jitLLM on your own GPU | 103 | ✓ | ✓ | ✓ | **14GB** default | [jitllm](https://github.com/beehive-lab/jitllm) |
| [L07](demos/L07-tornadovmpulse) | TornadoVMPulse | 49 | ◐ no power panel | ✓ | ◐ no power panel | < 100 MB | [TornadoVMPulse](https://github.com/beehive-lab/TornadoVMPulse) |
| [L08](demos/L08-tornadoviz) | TornadoViz | 50 | ✓ | ✓ | ✓ | < 100 MB | [TornadoViz](https://github.com/beehive-lab/TornadoViz) |
| [L09](demos/L09-jitllm-profiling) | jitLLM, then profile it | 104 (hidden) | ◐ no Nsight Systems | ✓ | ◐ no Nsight Systems | **14GB** default | [jitllm](https://github.com/beehive-lab/jitllm) |
| [L10](demos/L10-devoxxgenie) | DevoxxGenie: a local LLM inside your IDE | 108 | ✓ | ✓ | ✓ | **14GB** default | [jitllm](https://github.com/beehive-lab/jitllm/tree/feature/stream-usage) + [DevoxxGenie fork](https://github.com/stratika/DevoxxGenieIDEAPlugin/tree/feature/jitllm-openai-server) |
| [L11](demos/L11-flink-sql-gpu) | An SQL operator on the GPU | 111 | ✗ | ✓ | ✗ | TODO | `flink-accelerator-tornadovm` (not public yet) |
| [L12](demos/L12-flink-fleet-triage) | Fleet telemetry triage | 114 | ✗ | ✓ | ✗ | TODO | `flink-accelerator-tornadovm` (not public yet) |
| [L13](demos/L13-kotlin) | TornadoVM for Kotlin (WIP) | 117 | ✓ | ✓ | ✓ | < 100 MB | [TornadoVM PR #1123](https://github.com/beehive-lab/TornadoVM/pull/1123) |

The ✗ entries come from what the demo uses: cuBLAS (L05) is an NVIDIA library, and RAPIDS cuDF (L11, L12) runs on Linux with NVIDIA GPUs. L09's Nsight Systems part records CUDA activity, so it needs an NVIDIA GPU with the CUDA backend. Support marked ✓ or ◐ follows what each demo's code requires; rehearse it on every platform before relying on it.

## GPU memory

Two budgets matter, and both are set in [`env/versions.env`](env/versions.env) and can be overridden for one run:

| Budget | Default | Who needs more | Override |
|---|---|---|---|
| TornadoVM device memory (`-Dtornado.device.memory`) | 4GB | your own kernels with large arrays; none of the scripted demos | `TORNADO_DEVICE_MEMORY=8GB demos/L04-cuda-tilecontext/run.sh 4096` |
| jitLLM device budget (`--gpu-memory`) | 14GB | 3–7B models: 15GB+; 8B+ models: 20GB+ | `--gpu-memory 20GB` on the `./jitllm` command |

On a GPU smaller than a budget, lower it. jitLLM then reports how much the model actually needs (error `GPUL-MEM-001`, with a per-component plan). On macOS the memory is unified and the GPU may use only part of it, so a 16GB Mac may need a budget below 14GB; `scripts/check-env.sh` prints what your machine has. Details per demo are in [L06](demos/L06-jitllm/README.md#gpu-memory).

## Checking that the demos run

`scripts/run-all.sh` runs every scripted demo on your machine and reports PASS, SKIP or FAIL for each, with one log per demo in `logs/<date>/`. It is a setup check before the session, not a benchmark. Every scripted run sets `-Dtornado.recover.bailout=False`, so a kernel that fails to compile fails visibly instead of quietly running on the CPU and looking like a pass.

## Open items

- [ ] Rehearse every demo on macOS · Metal, Linux · CUDA and Linux · OpenCL.
- [ ] Record the GPU memory L11 and L12 need.
- [ ] Publish `flink-accelerator-tornadovm` (L11, L12), or move its scripts here.
- [ ] Add the download URL for Qwen3-0.6B FP16 (L12).
- [ ] Pin commits for every external repository in `env/versions.env`.
- [ ] Confirm that jitLLM `feature/stream-usage` works with the 7.1.0 SDK (L10); a source build needs TornadoVM develop.
- [ ] Confirm L05 runs with the 7.1.0 SDK; the CUDA demos repository defaults to 7.0.0.

## Layout

```
env/versions.env        versions, repositories, branches, model names, memory budgets
scripts/check-env.sh    SDK, backends, GPU memory, and which demos apply here
scripts/run-all.sh      checks that every scripted demo runs: PASS / SKIP / FAIL, logs to logs/
scripts/lib.sh          shared by the demo scripts: backend detection, JVM flags, memory budget
demos/Lnn-<name>/       one folder per demo: README.md, plus run.sh or sources when the code lives here
```
