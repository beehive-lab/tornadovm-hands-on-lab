# L15 · Your own Maven project, then the Hybrid API

Start your own TornadoVM project with Maven. Step 1 runs one Java method on the GPU. Step 2, `FancyHybrid`, adds a vendor library as a Maven dependency and calls it from the same task graph as your Java kernels. `FancyHybrid` is the class behind demos 1 and 2 of *Java Goes CUDA-Native*.

**Runs on:** step 1 on every backend · step 2 with Apple MLX on macOS and with cuBLAS on Linux · CUDA · **Needs:** [Setup once](../../README.md#setup-once) and TornadoVM 7.3.1 · **Code:** [`src/`](src) here

## Setup, once

The TornadoVM artifacts on Maven Central are 7.3.1, so this demo runs on its own 7.3.1 SDK:

```bash
sdk install tornadovm 7.3.1-jdk22plus-metal      # macOS;  or -cuda (NVIDIA), -opencl (Intel, AMD)
                                                 # answer n to making it the default
```

You don't need to install Maven: `./mvnw` downloads it on the first run.

## Run

```bash
demos/L15-maven-starter/run.sh
```

The script builds with `./mvnw`, runs `HelloTornado`, then `FancyHybridMlx` (macOS) or `FancyHybrid` (CUDA), at 2048 × 4096 and at 300 × 1000. On OpenCL it skips step 2. It also writes `tornado.args`, the JVM flags of its SDK, which the IntelliJ run configurations use.

## In IntelliJ IDEA

1. Run `demos/L15-maven-starter/run.sh` once. It writes `tornado.args`.
2. Open the lab folder in IntelliJ (`File → Open…`, the repository root). Its [`pom.xml`](../../pom.xml) lists the Maven demos, L03 and L15, so IntelliJ imports both. If the lab was open before that pom existed, click `Load Maven Project` when IntelliJ offers it. For the talk, you can open `demos/L15-maven-starter` alone instead, so the window shows nothing but L15.
   Don't accept IntelliJ's quick-fixes for red imports ("Add library to classpath", "Mark as Sources Root", "Move to package"). They mean the pom was not imported, and the fixes move files out of `src/`. Import the pom instead.
3. Pick a run configuration from the toolbar: `L15 1 · HelloTornado`, `L15 2 · FancyHybridMlx (Apple MLX)` on a Mac, or `L15 2 · FancyHybrid (cuBLAS, NVIDIA)` on a CUDA machine. They come from [`.run/`](.run), and all three pass `@tornado.args`.

The ▶ in the editor gutter runs plain `java`, without TornadoVM, and fails with `Tornado API Implementation class not specified. Did you remember to add @tornado-argfile?`. Use the run configurations above, or add `@tornado.args` to the VM options of your own.

Both hybrid source folders are on by themselves: the `mlx` profile on macOS, and the `cublas` profile everywhere, because `tornado-cublas` compiles anywhere. So on a Mac you can read `FancyHybrid` in the editor and run `FancyHybridMlx`. The Maven tool window shows both profiles as ticked.

Run IntelliJ on a JDK 22 or newer (`File → Project Structure → SDK`). `tornado.args` adds JVMCI flags that the JDK must accept.

## You should see

- **Step 1:** `Result is correct for 16777216 elements`. The first execution includes the JIT compilation, about 150 ms. The next nine take about 3 ms each on an M4 Pro.
- **Step 2:** five executions of a 2048 × 4096 layer, each `correct`, then `All executions correct`, and the same for 300 × 1000. The first execution takes 120–170 ms, and the rest 1–2 ms on an M4 Pro.

## Maven compiles, the SDK runs

| | What it gives you | Where it comes from |
|---|---|---|
| Maven dependencies | the API to compile against: `TaskGraph`, `@Parallel`, `FloatArray`, `Mlx`, `CuBlas` | Maven Central, `io.github.beehive-lab:tornado-*` |
| TornadoVM SDK | the JIT compiler, the GPU backend and the native libraries that run the code | SDKMAN!, in `$TORNADOVM_HOME` |

The dependencies are `provided`: the SDK's `tornado` launcher puts its own copy of every TornadoVM jar on the module path at run time. Keep the two at the same version. `run.sh` passes `STARTER_TORNADOVM_MAVEN` from [`env/versions.env`](../../env/versions.env) to Maven.

```xml
<dependency>
    <groupId>io.github.beehive-lab</groupId>
    <artifactId>tornado-api</artifactId>            <!-- step 2 adds tornado-mlx or tornado-cublas -->
    <version>${tornadovm.version}</version>
    <scope>provided</scope>
</dependency>
```

The same build runs in three ways:

```bash
cd demos/L15-maven-starter && ./mvnw -q package
tornado -cp target/classes com.example.tornado.HelloTornado                               # the SDK's launcher
./mvnw -q exec:exec                                                                       # Maven calls `tornado`
java @$TORNADOVM_HOME/tornado-argfile -cp target/classes com.example.tornado.HelloTornado  # plain java, as IDEs do
```

## Step 2 · FancyHybrid

A dense neural-network layer, `y = relu(W · x/255 + b)`, in three tasks on the same device buffers:

```
transferToDevice ─▶ task("scale") ─▶ libraryTask("sgemv") ─▶ task("bias") ─▶ transferToHost
  weights, bias        Java, JIT         cuBLAS or MLX           Java, JIT          output
  input
```

Read the class in two halves, as on the slides:

- **What to run: the `TaskGraph`.** `W` and `b` go to the device once (`FIRST_EXECUTION`), the input every run (`EVERY_EXECUTION`).
- **How to run it: the `TornadoExecutionPlan`.** It sets `withDevice`, `withGridScheduler`, and `withCUDAGraph()`, which captures the chain once and replays it after that.

Each run gets a new input and is checked against the CPU, so every CUDA-graph replay is checked on fresh data.

Each library is a Maven profile that adds one dependency and one source folder. Both turn on by themselves where they apply: `mlx` on macOS, `cublas` everywhere. `-DskipCublas` turns cuBLAS off.

| | `FancyHybrid` · cuBLAS | `FancyHybridMlx` · MLX |
|---|---|---|
| Profile | `cublas`, on everywhere | `mlx`, on on macOS |
| SDK | `7.3.1-jdk22plus-cuda` | `7.3.1-jdk22plus-metal` |
| Library task | `CuBlas::cublasSgemv, OP_T, k, m, 1, W, k, x, 1, 0, y, 1` | `Mlx::matmul, W, x, y, m, k, 1` |
| Layout | column-major, so `CUBLAS_OP_T` | row-major, like Java |
| Plan | `withDevice`, `withGridScheduler`, `withCUDAGraph` | `withDevice`, `withGridScheduler` |

For demos 1 and 2 of the talk, open the project in IntelliJ ([above](#in-intellij-idea)). Walk `FancyHybrid.java` (the TaskGraph, then the plan), run `FancyHybridMlx` on the Mac, then run `FancyHybrid` on the GPU server:

```bash
cd demos/L15-maven-starter && ./mvnw -q -Pcublas package
tornado --printKernel -cp target/classes com.example.tornado.hybrid.FancyHybrid                       # CUDA for scale and bias
tornado --enableProfiler console -cp target/classes com.example.tornado.hybrid.FancyHybrid            # time per task
tornado --jvm="-Dtornado.print.bytecodes=True" -cp target/classes com.example.tornado.hybrid.FancyHybrid 2048 4096 3   # capture, then replays
```

## Notes

- **The cuBLAS argument order.** cuBLAS is column-major. A row-major `M × K` matrix is the column-major `K × M` matrix `Wᵀ`, so the call is `OP_T, K, M, …, lda = K`. With a square matrix, swapping the two makes no difference. `run.sh` also runs 300 × 1000 so a swap shows up.
- **Kernel names must not clash with GPU built-ins.** A kernel method called `normalize` fails with `Java method name corresponds to an OpenCL Token`.
- **`withCUDAGraph()` fails on Metal in 7.3.1** with `does not support execution graphs`, even for a one-task graph. `FancyHybridMlx` leaves it out. The cause is in TornadoVM: `TornadoVMGraphCompiler` never calls its own guard, `shouldEmitExecutionGraphBytecodes()`.
- **`provided`, not `compile`.** A fat jar with a second copy of the TornadoVM jars clashes with the SDK's modules.
- **A cuBLAS build on a Mac** compiles, because `tornado-cublas` is plain Java, but it runs only with a cuda SDK.
