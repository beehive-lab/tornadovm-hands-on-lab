# L17 · Matrix multiplication: plain Java, then the GPU with JIT, then AOT

Start from a matrix multiplication in plain Java, with no TornadoVM in it. Make it a GPU kernel yourself, with TornadoInsight checking the code as you type, and run it with TornadoVM's JIT compiler from IntelliJ. Then start the same application ahead of time: from a Project Leyden AOT cache, and as a GraalVM native image. This is the flow of slide 33 of *Write Once, Accelerate Everywhere*.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once), TornadoVM 8.0.0, JDK 25 or newer, IntelliJ IDEA with [TornadoInsight](../L03-tornadoinsight), and a GraalVM for JDK 25+ for the native image · **Code:** [`MatrixMultiplication.java`](src/main/java/com/example/matmul/MatrixMultiplication.java)

The repository holds only the starting point: plain Java and a `pom.xml` with no dependency. You make every TornadoVM change; don't commit them.

## Setup, once

The Leyden AOT cache and `tornado-native-image` ship from TornadoVM 8.0.0, so this demo runs on its own 8.0.0 SDK:

```bash
sdk install tornadovm 8.0.0-jdk22plus-metal      # macOS;  or -cuda (NVIDIA), -opencl (Intel, AMD)
                                                 # answer n to making it the default
sdk install java 25.0.2-open                     # the lab's JDK; the AOT cache needs JDK 25+
sdk list java | grep graal                       # pick a GraalVM for JDK 25+, for the native image
```

In IntelliJ, open the lab folder (`File → Open…`, the repository root): its [`pom.xml`](../../pom.xml) imports L17 as a Maven module. In `Settings → TornadoInsight`, set the TornadoVM root to the 8.0.0 SDK, `~/.sdkman/candidates/tornadovm/8.0.0-jdk22plus-metal` (or `-cuda`, `-opencl`).

## Phase 1 · From plain Java to the GPU, with JIT

### Step 0 · Run the plain Java

Run `L17 1 · MatrixMultiplication (plain Java)` from the IntelliJ toolbar, or:

```bash
demos/L17-matmul-jit-aot/run.sh            # [size] [iterations], default 1024 5
```

`matrixMultiplication` computes `C = A · B` for square matrices stored row by row in flat `float[]` arrays: three nested loops, one dot product per output element. Write down the time per execution: this is the CPU time to beat, about 900 ms at 1024 × 1024 on an M4 Pro.

`run.sh` also writes `tornado.args`, the JVM flags of the 8.0.0 SDK, which the IntelliJ run configuration of step 3 uses.

### Step 1 · Add the TornadoVM API to `pom.xml`

Replace the comment in `<dependencies>` with:

```xml
<dependency>
    <groupId>io.github.beehive-lab</groupId>
    <artifactId>tornado-api</artifactId>
    <version>${tornadovm.version}</version>   <!-- 8.0.0-jdk22plus -->
    <scope>provided</scope>
</dependency>
```

Click `Load Maven Changes` in IntelliJ. The scope is `provided`: Maven compiles against this jar, and the SDK brings its own TornadoVM jars at run time ([L15](../L15-maven-starter#maven-compiles-the-sdk-runs) explains why).

### Step 2 · Make it parallel, with TornadoInsight

Change the method, then give it a `main` that runs it on the GPU. TornadoInsight marks what a GPU cannot run as you type: objects such as `String`, exceptions, recursion, calls into other classes.

1. **The data.** Replace `float[]` with `FloatArray` (`uk.ac.manchester.tornado.api.types.arrays`), which lives off-heap so TornadoVM can hand it to the GPU. `a[i]` becomes `a.get(i)`, and `c[i] = x` becomes `c.set(i, x)`.
2. **The parallelism.** Pick one of the two APIs:
   - **Loop Parallel API:** annotate the two outer loops, `for (@Parallel int i = 0; …)` and `for (@Parallel int j = 0; …)`. The method still runs as plain Java on the CPU, so it is also your reference result.
   - **Kernel API:** write a second method that takes a `KernelContext` first, reads `i = context.globalIdx` and `j = context.globalIdy`, and keeps only the `k` loop. It needs a `WorkerGrid2D(size, size)` in a `GridScheduler` (step 4).
3. **Run one task from TornadoInsight.** In the TornadoInsight window, select the method and run it. The plugin generates the `main` and the `TaskGraph`, runs the task on the GPU and prints the generated kernel. If the method is not listed, the checker found something a GPU cannot run.
4. **Write `main`.** Build a `TaskGraph`: `transferToDevice(FIRST_EXECUTION, a, b)`, `task("t0", MatrixMultiplication::matrixMultiplication, a, b, c, size)`, `transferToHost(EVERY_EXECUTION, c)`. Run it with a `TornadoExecutionPlan`, timing each `execute()`. With the Kernel API, pass the `KernelContext` as the task's first argument and add `withGridScheduler(new GridScheduler("s0.t0", worker))` to the plan. Check the result against the method run on the CPU; float sums differ in the last bits, so compare with a tolerance.

The [solution](#solution) is at the end, if you are stuck.

### Step 3 · Run it with JIT, from IntelliJ

Run `L17 2 · MatrixMultiplication (TornadoVM JIT)`. It passes `@tornado.args` as VM options; run `run.sh` once first to write that file. The ▶ in the editor gutter runs plain `java` and fails with `Tornado API Implementation class not specified`.

From the command line, `run.sh` now sees that the class calls TornadoVM and runs it through the SDK:

```bash
demos/L17-matmul-jit-aot/run.sh
```

**You should see** (M4 Pro, 1024 × 1024): the first execution takes about 150–200 ms, because TornadoVM JIT-compiles the method to a GPU kernel on its first run. The next executions take about 3–6 ms, more than 100 times faster than the plain Java. Then `Result is correct`.

To see the kernel TornadoVM generated:

```bash
cd demos/L17-matmul-jit-aot && tornado --printKernel -cp target/matmul.jar com.example.matmul.MatrixMultiplication 1024 1
```

## Phase 2 · Ahead of time: Project Leyden and GraalVM native image

With JIT, every start pays for starting the JVM, loading and linking the TornadoVM runtime and its drivers, and warming up TC, TornadoVM's kernel compiler. That cost is the same for every run, and it dominates a short one. Two ways to pay most of it ahead of time:

| | What is stored ahead of time | Run with |
|---|---|---|
| **Project Leyden AOT cache** (JDK 25+, JEP 483/514/515) | the classes loaded and linked by a training run, resolved lambdas, and method profiles | the same JVM: `java -XX:AOTCache=matmul.aot …` |
| **GraalVM native image** | the whole application, TornadoVM runtime, drivers and TC compiled into one executable | no JVM: `./matmul` |

In both, the kernel is still compiled when the application runs: TC specialises it on the real arguments, as on the JVM. What moves ahead of time is the work around that compile.

`aot.sh` builds the jar, starts the application all three ways with a short workload (256 × 256, one execution), and times each start, as the median of 5:

```bash
demos/L17-matmul-jit-aot/aot.sh            # [jit|leyden|native|all] [size], default all 256
```

**You should see** (M4 Pro, Metal, JDK 25, GraalVM CE for JDK 25), wall time of the whole process:

| Start | Time |
|---|---:|
| `jit` · `java @tornado.args` | 420 ms |
| `leyden` · `java -XX:AOTCache=target/matmul.aot` | 288 ms |
| `native` · `target/matmul` | 91 ms |

### The Leyden AOT cache, by hand

`tornado` can train and use the cache itself: the first run writes it, the next ones start from it.

```bash
cd demos/L17-matmul-jit-aot && ./mvnw -q package
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
cd demos/L17-matmul-jit-aot && ./mvnw -q package
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
- **The JIT row of `aot.sh` is not the IntelliJ run.** It uses the same trimmed module path as the cache, so the two rows differ only by the cache.
- **Full guide:** [`LEYDEN_GRAALVM_NATIVE_IMAGE.md`](https://github.com/beehive-lab/TornadoVM/blob/master/LEYDEN_GRAALVM_NATIVE_IMAGE.md) in TornadoVM: AppCDS for JDK 21, loading one backend only (`-Dtornado.enabled.backends`), and measurements on CUDA.

## Solution

<details>
<summary>Both kernels and a <code>main</code> that runs either one</summary>

```java
package com.example.matmul;

import java.util.Random;

import uk.ac.manchester.tornado.api.GridScheduler;
import uk.ac.manchester.tornado.api.KernelContext;
import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.WorkerGrid2D;
import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;

public class MatrixMultiplication {

    /** Loop Parallel API: TornadoVM maps i and j to a 2D grid of GPU threads. On the CPU, the reference. */
    public static void matrixMultiplication(FloatArray a, FloatArray b, FloatArray c, int size) {
        for (@Parallel int i = 0; i < size; i++) {
            for (@Parallel int j = 0; j < size; j++) {
                float sum = 0.0f;
                for (int k = 0; k < size; k++) {
                    sum += a.get(i * size + k) * b.get(k * size + j);
                }
                c.set(i * size + j, sum);
            }
        }
    }

    /** Kernel API: one GPU thread per (i, j), as in CUDA or OpenCL. */
    public static void matrixMultiplication(KernelContext context, FloatArray a, FloatArray b, FloatArray c, int size) {
        int i = context.globalIdx;
        int j = context.globalIdy;
        float sum = 0.0f;
        for (int k = 0; k < size; k++) {
            sum += a.get(i * size + k) * b.get(k * size + j);
        }
        c.set(i * size + j, sum);
    }

    public static void main(String[] args) throws TornadoExecutionPlanException {
        int size = args.length > 0 ? Integer.parseInt(args[0]) : 1024;
        int iterations = args.length > 1 ? Integer.parseInt(args[1]) : 5;
        boolean kernelApi = args.length > 2 && args[2].equals("kernel");   // ... 1024 5 kernel

        FloatArray a = new FloatArray(size * size);
        FloatArray b = new FloatArray(size * size);
        FloatArray c = new FloatArray(size * size);
        Random random = new Random(42);
        for (int i = 0; i < size * size; i++) {
            a.set(i, random.nextFloat());
            b.set(i, random.nextFloat());
        }

        TaskGraph taskGraph = new TaskGraph("s0").transferToDevice(DataTransferMode.FIRST_EXECUTION, a, b);
        GridScheduler gridScheduler = null;
        if (kernelApi) {
            KernelContext context = new KernelContext();
            taskGraph.task("t0", MatrixMultiplication::matrixMultiplication, context, a, b, c, size);
            WorkerGrid2D worker = new WorkerGrid2D(size, size);
            worker.setLocalWork(16, 16, 1);
            gridScheduler = new GridScheduler("s0.t0", worker);
        } else {
            taskGraph.task("t0", MatrixMultiplication::matrixMultiplication, a, b, c, size);
        }
        taskGraph.transferToHost(DataTransferMode.EVERY_EXECUTION, c);

        System.out.println("Matrix multiplication, " + size + " x " + size + ", " + iterations + " executions, "
                + (kernelApi ? "Kernel API" : "Loop Parallel API"));
        double flop = 2.0 * size * size * size;
        try (TornadoExecutionPlan plan = new TornadoExecutionPlan(taskGraph.snapshot())) {
            if (gridScheduler != null) {
                plan.withGridScheduler(gridScheduler);
            }
            for (int it = 0; it < iterations; it++) {
                long start = System.nanoTime();
                plan.execute();
                long end = System.nanoTime();
                double ms = (end - start) / 1e6;
                System.out.printf("  execution %d: %8.2f ms  %7.2f GFLOP/s%n", it, ms, flop / (ms * 1e6));
            }
        }

        FloatArray expected = new FloatArray(size * size);
        matrixMultiplication(a, b, expected, size);   // the same method, run by the JVM on the CPU
        for (int i = 0; i < size * size; i++) {
            if (Math.abs(c.get(i) - expected.get(i)) > 0.01f * Math.abs(expected.get(i)) + 1e-3f) {
                System.out.println("WRONG at " + i + ": " + c.get(i) + " != " + expected.get(i));
                System.exit(1);
            }
        }
        System.out.println("Result is correct");
    }
}
```

</details>
