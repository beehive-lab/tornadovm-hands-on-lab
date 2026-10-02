# L13 · TornadoVM for Kotlin (work in progress)

Kotlin compiles to JVM bytecode, so Kotlin kernels run on the same OpenCL, CUDA and Metal backends.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL (tile examples need CUDA) |
| GPU memory | under 100 MB; the TornadoVM default (4GB) is plenty for the examples |
| Code | [TornadoVM PR #1123](https://github.com/beehive-lab/TornadoVM/pull/1123), branch `kotselidis:feature/kotlin-execution`; module docs in `tornado-kotlin/README.md` |
| Status | open PR against `develop` (7.0.2-dev); **not in the 7.0.1 SDK** |

## Build

```bash
git clone https://github.com/beehive-lab/TornadoVM.git && cd TornadoVM
git fetch origin pull/1123/head:kotlin && git checkout kotlin
make jdk22plus BACKEND=metal KOTLIN=1     # macOS
make jdk22plus BACKEND=cuda KOTLIN=1      # Linux, NVIDIA
make jdk22plus BACKEND=opencl KOTLIN=1    # Linux, Intel or AMD
source setvars.sh
```

`KOTLIN=1` is opt-in: the default build never downloads the Kotlin toolchain.

## Test and run

```bash
tornado-test --kotlin -V
tornado -m tornado.kotlin.examples/uk.ac.manchester.tornado.kotlin.examples.VectorAdd
tornado -m tornado.kotlin.examples/uk.ac.manchester.tornado.kotlin.examples.MatrixMultiplication
tornado -m tornado.kotlin.examples/uk.ac.manchester.tornado.kotlin.examples.tile.TileMatrixMultiply   # CUDA only
```

## What to look for

- `parallelFor` stands in for `@Parallel`, which `kotlinc` drops on local variables.
- Runtime rewrites apply only to classes compiled by `kotlinc`; `-Dtornado.kotlin.support=false` turns them off.
- Kotlin also reaches `KernelContext`, `@Reduce`, cuBLAS and CUDA Tile. Tile examples need the CUDA backend.
