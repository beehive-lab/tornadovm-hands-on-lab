# TornadoVM Hands-On Lab

Every demo from *From Install to Insight: A Hands-On GPU Lab for Java Developers*, reproducible on macOS and Linux. The demos are numbered `L01`–`L13` in the order the lab runs them.

## Setup once

```bash
sdk install java 25.0.2-open
sdk install tornadovm 7.1.0-jdk22plus-metal      # macOS, Apple Silicon
sdk install tornadovm 7.1.0-jdk22plus-cuda       # Linux, NVIDIA
sdk install tornadovm 7.1.0-jdk22plus-opencl     # Linux, Intel or AMD

scripts/check-env.sh      # prints the SDK, backends and GPU memory, and which demos run here
```

For L06–L10 (jitLLM), also run `demos/L06-jitllm/setup.sh` once.

**Run every command from the root of this repository.** Scripts print each command before running it. Anything a demo clones or downloads stays inside its folder, and git ignores it.

## Demos

✓ runs · ◐ runs with a platform variant or a part skipped · ✗ not available · slides from the deck of 2 October 2026

| ID | Demo | Slide | macOS · Metal | Linux · CUDA | Linux · OpenCL |
|---|---|---|---|---|---|
| [L01](demos/L01-sdkman) | SDKMAN! | 42 | ✓ | ✓ | ✓ |
| [L02](demos/L02-metal-look-inside) | Run on the GPU, then look inside | 46 (hidden) | ✓ | ✓ | ✓ |
| [L03](demos/L03-tornadoinsight) | Debug with TornadoInsight | 47 | ✓ | ✓ | ✓ |
| [L04](demos/L04-cuda-tilecontext) | CUDA TileContext | 88 | ✗ | ✓ | ✗ |
| [L05](demos/L05-hybrid-cublas) | Hybrid API with cuBLAS | 93 | ✗ | ✓ | ✗ |
| [L06](demos/L06-jitllm) | jitLLM on your own GPU | 103 | ✓ | ✓ | ✓ |
| [L07](demos/L07-tornadovmpulse) | TornadoVMPulse | 49 | ◐ | ✓ | ◐ |
| [L08](demos/L08-tornadoviz) | TornadoViz | 50 | ✓ | ✓ | ✓ |
| [L09](demos/L09-jitllm-profiling) | jitLLM, then profile it | 104 (hidden) | ◐ | ✓ | ◐ |
| [L10](demos/L10-devoxxgenie) | DevoxxGenie: a local LLM inside your IDE | 108 | ✓ | ✓ | ✓ |
| [L11](demos/L11-flink-sql-gpu) | An SQL operator on the GPU | 111 | ✗ | ✓ | ✗ |
| [L12](demos/L12-flink-fleet-triage) | Fleet telemetry triage | 114 | ✗ | ✓ | ✗ |
| [L13](demos/L13-kotlin) | TornadoVM for Kotlin (work in progress) | 117 | ✓ | ✓ | ✓ |

Each demo's README explains its ◐ or ✗.

## Check that the demos run

```bash
scripts/run-all.sh        # PASS / SKIP / FAIL per scripted demo, logs in logs/<date>/
```

This checks your setup before the session; it is not a benchmark. Every script turns off TornadoVM's fallback to the CPU (`-Dtornado.recover.bailout=False`), so a kernel that fails to compile shows up as a failure instead of passing on the CPU.

## GPU memory

| Budget | Default | Override for one run |
|---|---|---|
| TornadoVM device memory | 4GB | `TORNADO_DEVICE_MEMORY=8GB demos/L02-metal-look-inside/run.sh` |
| jitLLM (L06–L10) | 14GB | `JITLLM_GPU_MEMORY=8GB demos/L06-jitllm/jitllm.sh …` |

If your GPU has less than a budget, lower the budget. On macOS the GPU can use only part of the unified memory, so a 16GB Mac needs a jitLLM budget below 14GB. Defaults are in [`env/versions.env`](env/versions.env), which pins every version, repository and branch.

## Open items

- [ ] Rehearse every demo on macOS · Metal, Linux · CUDA and Linux · OpenCL.
- [ ] Rehearse L11 and L12 from a fresh `1-fetch.sh`, and record the GPU memory they need.
- [ ] Pin commits for every external repository in `env/versions.env`.
- [ ] Merge jitLLM `feature/stream-usage` into `main`, so DevoxxGenie shows token counts with the L06 build (L10).
- [ ] Add a 7.1.0 SDK profile to the CUDA demos repository; it pins 7.0.0 (L04, L05).

## Layout

```
env/versions.env        versions, repositories, branches, model, memory budgets
scripts/check-env.sh    SDK, backends, GPU memory, and which demos apply here
scripts/run-all.sh      runs every demos/*/run.sh: PASS / SKIP / FAIL
scripts/*.sh            helpers the demo scripts source
demos/Lnn-<name>/       README.md, plus the scripts or sources that live here
```
