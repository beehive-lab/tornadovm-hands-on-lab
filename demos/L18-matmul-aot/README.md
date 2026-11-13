# L18 · Matrix multiplication, ahead of time: a Leyden AOT cache and a GraalVM native image

L17 ends with a matrix multiplication running on the GPU through TornadoVM's JIT compiler. L18 starts that application ahead of time: from a Project Leyden AOT cache, and as a GraalVM native image. Then it times all three starts side by side. This is the second half of slide 33 of *Write Once, Accelerate Everywhere*.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once), TornadoVM 8.1.0, JDK 25 or newer, and a GraalVM for JDK 25+ for the native image · **Code:** [`MatrixMultiplication.java`](src/main/java/com/example/matmul/MatrixMultiplication.java)

The class is L17's [solution](../L17-matmul-jit#solution), committed, so L18 runs straight from a clone, whatever state your L17 exercise is in. It uses the Loop Parallel API (`@Parallel`) by default; `kernel` as the third argument, or `API=kernel` for `aot.sh`, runs the Kernel API version. Every run checks the GPU result against the same method run on the CPU.

## Setup, once

The Leyden AOT cache and `tornado-native-image` ship from TornadoVM 8.0.0. L18 runs on the same 8.1.0 SDK as L17:

```bash
sdk install tornadovm 8.1.0-jdk22plus-metal      # macOS;  or -cuda (NVIDIA), -opencl (Intel, AMD)
                                                 # answer n to making it the default
sdk install java 25.0.2-open                     # the lab's JDK; the AOT cache needs JDK 25+
sdk list java | grep graal                       # pick a GraalVM for JDK 25+, for the native image
```

`native-image` links the executable with the system's C toolchain:

```bash
xcode-select --install                                        # macOS
sudo apt-get install build-essential zlib1g-dev               # Linux: Debian, Ubuntu
sudo dnf install gcc glibc-devel zlib-devel libstdc++-static  # Linux: Fedora, RHEL
```

## Run it with JIT first

```bash
demos/L18-matmul-aot/run.sh                # [size] [iterations] [kernel], default 1024 5, Loop Parallel API
```

**You should see** what L17's step 3 shows: a first execution of about 150–200 ms while TornadoVM compiles the kernel, then 3–6 ms per execution (M4 Pro, 1024 × 1024), and `Result is correct`.

## Start it ahead of time

With JIT, every start pays for starting the JVM, loading and linking the TornadoVM runtime and its drivers, and warming up TC, TornadoVM's kernel compiler. That cost is the same for every run, and it dominates a short one. Two ways to pay most of it ahead of time:

| | What is stored ahead of time | Run with |
|---|---|---|
| **Project Leyden AOT cache** (JDK 25+, JEP 483/514/515) | the classes loaded and linked by a training run, resolved lambdas, and method profiles | the same JVM: `java -XX:AOTCache=matmul.aot …` |
| **GraalVM native image** | the whole application, TornadoVM runtime, drivers and TC compiled into one executable | no JVM: `./matmul` |

In both, the kernel is still compiled when the application runs: TC specialises it on the real arguments, as on the JVM. What moves ahead of time is the work around that compile.

`aot.sh` builds the jar, then starts the application all three ways with a short workload (256 × 256, one execution), one act per start, as L14 draws the Hybrid API. Each act times 5 starts and shows each one as it ends. The script ends with the three starts side by side, a bar each, and the checks:

```bash
demos/L18-matmul-aot/aot.sh            # [jit|leyden|native|all] [size], default all 256
NO_PAUSE=1 demos/L18-matmul-aot/aot.sh # no [enter] between acts; RUNS=n times n starts; NO_COLOR=1
API=kernel demos/L18-matmul-aot/aot.sh # the Kernel API version; the Loop Parallel API is the default
```

Every step's output is in `target/logs/`.

**You should see** (M4 Pro, Metal, JDK 25, GraalVM CE for JDK 25), the median wall time of the whole process. Each bar splits it into the start-up and the first `execute()`, where TornadoVM plans the task graph, TC compiles the kernel, the GPU driver builds it, and the GPU runs it:

```
    jit     java @tornado.args   █████████████████████████░░░░░░░░░░░░░░░░░░░    477 ms
    leyden  java -XX:AOTCache    ███████████░░░░░░░░░░░                          241 ms   2.0× faster
    native  target/matmul        ████████░                                       102 ms   4.7× faster ★
```

The cache makes both parts faster: the classes TC needs are already loaded and linked. The native image also makes the first `execute()` faster, about 16 ms instead of 200 ms, because TC itself is compiled ahead of time and starts warm.

### The Leyden AOT cache, by hand

`tornado` can train and use the cache itself: the first run writes it, the next ones start from it.

```bash
cd demos/L18-matmul-aot && ./mvnw -q package
tornado --aotCache target/matmul.aot -cp target/matmul.jar com.example.matmul.MatrixMultiplication 256 1   # training run
tornado --aotCache target/matmul.aot -cp target/matmul.jar com.example.matmul.MatrixMultiplication 256 1   # from the cache
```

For the full gain, run `java` directly, as `aot.sh` does: the `tornado` launcher is a Python script that costs about 90 ms per start, and it keeps the SDK's test modules on the module path. `aot.sh` writes `target/aot.args`, `tornado.args` with a module path that holds only the runtime's modules, and runs:

```bash
java @target/aot.args -cp target/matmul.jar -XX:AOTCacheOutput=target/matmul.aot com.example.matmul.MatrixMultiplication 256 1   # training
java @target/aot.args -cp target/matmul.jar -XX:AOTCache=target/matmul.aot      com.example.matmul.MatrixMultiplication 256 1   # production
```

Add `-Xlog:aot` to check: a cache in use logs `Opened AOT cache` and `full module graph: enabled`.

### The GraalVM native image, by hand

```bash
cd demos/L18-matmul-aot && ./mvnw -q package
export GRAALVM_HOME=~/.sdkman/candidates/java/<a GraalVM for JDK 25+>
export NATIVE_IMAGE_OPTIONS=-H:-VectorAPISupport     # GraalVM 25.2+, see Notes
tornado-native-image -cp target/matmul.jar -o target/matmul com.example.matmul.MatrixMultiplication 256 1
target/matmul 1024 5                                  # no JVM; -D options work as on the JVM
```

`tornado-native-image` first runs the application on GraalVM's JVM with the native-image agent, which records the reflection, resources and FFM downcalls it uses. Then it builds the executable from that, in about 30 s. Give the tracing run arguments that compile and launch every kernel: a code path it never ran fails in the executable.

## Notes

- **An AOT cache wants exactly the training run's set-up:** the same JDK build, the same flags, the same class and module paths, and the application as a jar, not `target/classes`. A cache that doesn't match is ignored, and the start is slow again. `aot.sh` adds `-XX:AOTMode=on`, which makes a mismatch an error instead.
- **Retrain after any change** to the class, the SDK or the JDK: rerun `aot.sh`.
- **`Support for Arena.ofShared … is not available with Vector API support`** from `native-image`: GraalVM 25.2 turns on Vector API support, which refuses the shared arenas TornadoVM's drivers use. `-H:-VectorAPISupport` turns it off; `aot.sh` sets it.
- **The executable still needs the GPU driver** (Metal, `libcuda` or the OpenCL ICD), loaded at run time as on the JVM. It doesn't need the SDK.
- **The JIT row of `aot.sh` is not `run.sh`, nor L17's IntelliJ run.** It runs `java` directly, without the `tornado` launcher, and uses the same trimmed module path as the cache, so the two rows differ only by the cache.
- **Full guide:** [`LEYDEN_GRAALVM_NATIVE_IMAGE.md`](https://github.com/beehive-lab/TornadoVM/blob/master/LEYDEN_GRAALVM_NATIVE_IMAGE.md) in TornadoVM: AppCDS for JDK 21, loading one backend only (`-Dtornado.enabled.backends`), and measurements on CUDA.
