# L01 · SDKMAN!

Install the TornadoVM SDK in one line, run a built-in example, and generate the argfile that lets IDEs and build tools run TornadoVM.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL |
| GPU memory | under 100 MB; the TornadoVM default (4GB) is plenty |
| Code | in this repo: [`run.sh`](run.sh), using the SDK's built-in `tornado.examples` |

## Setup

```bash
sdk list tornadovm
sdk install tornadovm 7.1.0-jdk22plus-metal     # macOS
sdk install tornadovm 7.1.0-jdk22plus-cuda      # Linux, NVIDIA
sdk install tornadovm 7.1.0-jdk22plus-opencl    # Linux, Intel or AMD
```

## Run

```bash
./run.sh
```

## What to look for

- `sdk list tornadovm` shows the version grid: 7.1.0 × `jdk21` / `jdk22plus` × `opencl`, `cuda`, `metal`.
- `tornado --devices` lists devices as `backend:device` (for example `0:0`); that index is what `-Dtornado.device` takes later.
- `VectorAddInt` runs clean. That is the checkpoint before moving on.

Use the `jdk22plus` SDK unless you are pinned to JDK 21. After switching JDK, run `tornado --generate-argfile` again: the flags differ per JDK, and a stale argfile fails with `Unrecognized VM option EnableJVMCI`.
