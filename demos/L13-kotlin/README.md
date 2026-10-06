# L13 · TornadoVM for Kotlin (work in progress)

Kotlin compiles to JVM bytecode, so Kotlin kernels run on the same Metal, CUDA and OpenCL backends.

**Runs on:** every backend; the tile example needs CUDA · **Code:** [TornadoVM PR #1123](https://github.com/beehive-lab/TornadoVM/pull/1123), still open against `develop` and **not in the 7.1.0 SDK**, so this demo builds TornadoVM from source

## Setup, once

```bash
git clone https://github.com/beehive-lab/TornadoVM.git demos/L13-kotlin/TornadoVM
cd demos/L13-kotlin/TornadoVM
git fetch origin pull/1123/head:kotlin && git checkout kotlin
make jdk22plus BACKEND=metal KOTLIN=1      # macOS;   or BACKEND=cuda (NVIDIA), BACKEND=opencl (Intel, AMD)
```

`KOTLIN=1` makes the build download the Kotlin toolchain; the default build does not.

## Run

In the same folder. `setvars.sh` points this shell at the build, not at the lab's SDK:

```bash
source setvars.sh
tornado-test --kotlin -V
tornado -m tornado.kotlin.examples/uk.ac.manchester.tornado.kotlin.examples.VectorAdd
tornado -m tornado.kotlin.examples/uk.ac.manchester.tornado.kotlin.examples.MatrixMultiplication
tornado -m tornado.kotlin.examples/uk.ac.manchester.tornado.kotlin.examples.tile.TileMatrixMultiply   # CUDA only
```

## You should see

- `tornado-test` reports every Kotlin test as passed.
- Each example runs on your GPU, as the Java ones did in L01.

## Notes

- `parallelFor` stands in for `@Parallel`, because `kotlinc` drops annotations on local variables.
- The runtime rewrites only classes compiled by `kotlinc`. `-Dtornado.kotlin.support=false` turns the rewrites off.
- Kotlin also reaches `KernelContext`, `@Reduce`, cuBLAS and CUDA Tile. The module's own docs are `tornado-kotlin/README.md` in the clone.
