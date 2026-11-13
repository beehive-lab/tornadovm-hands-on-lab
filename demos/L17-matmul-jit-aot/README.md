# L17 · Matrix multiplication: plain Java, then the GPU with JIT, then AOT

Start from a matrix multiplication in plain Java, with no TornadoVM in it. Make it a GPU kernel yourself, with TornadoInsight checking the code as you type, and run it with TornadoVM's JIT compiler from IntelliJ. Look inside with tcirviz: the method at every stage of TC, TornadoVM's kernel compiler, from bytecode to GPU code. Then start the same application ahead of time: from a Project Leyden AOT cache, and as a GraalVM native image. This is the flow of slide 33 of *Write Once, Accelerate Everywhere*.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once), TornadoVM 8.1.0, JDK 25 or newer, IntelliJ IDEA with [TornadoInsight](../L03-tornadoinsight), and a GraalVM for JDK 25+ for the native image · **Code:** [`MatrixMultiplication.java`](src/main/java/com/example/matmul/MatrixMultiplication.java)

The repository holds only the starting point: plain Java and a `pom.xml` with no dependency. You make every TornadoVM change; don't commit them.

## Setup, once

The Leyden AOT cache and `tornado-native-image` ship from TornadoVM 8.0.0, this demo runs on its own 8.1.0 SDK:

```bash
sdk install tornadovm 8.1.0-jdk22plus-metal      # macOS;  or -cuda (NVIDIA), -opencl (Intel, AMD)
                                                 # answer n to making it the default
sdk install java 25.0.2-open                     # the lab's JDK; the AOT cache needs JDK 25+
sdk list java | grep graal                       # pick a GraalVM for JDK 25+, for the native image
```

In IntelliJ, open the lab folder (`File → Open…`, the repository root): its [`pom.xml`](../../pom.xml) imports L17 as a Maven module. In `Settings → TornadoInsight`, set the TornadoVM root to the 8.1.0 SDK, `~/.sdkman/candidates/tornadovm/8.1.0-jdk22plus-metal` (or `-cuda`, `-opencl`).

## Phase 1 · From plain Java to the GPU, with JIT

### Step 0 · Run the plain Java

Run `L17 1 · MatrixMultiplication (plain Java)` from the IntelliJ toolbar, or:

```bash
demos/L17-matmul-jit-aot/run.sh            # [size] [iterations], default 1024 5
```

`matrixMultiplication` computes `C = A · B` for square matrices stored row by row in flat `float[]` arrays: three nested loops, one dot product per output element. Write down the time per execution: this is the CPU time to beat, about 900 ms at 1024 × 1024 on an M4 Pro.

`run.sh` also writes `tornado.args`, the JVM flags of the 8.1.0 SDK, which the IntelliJ run configuration of step 3 uses.

### Step 1 · Add the TornadoVM API to `pom.xml`

Replace the comment in `<dependencies>` with:

```xml
<dependency>
    <groupId>io.github.beehive-lab</groupId>
    <artifactId>tornado-api</artifactId>
    <version>${tornadovm.version}</version>   <!-- 8.1.0-jdk22plus -->
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

### Step 4 · Look inside: the Java method on the GPU, with tcirviz

`--printKernel` shows only the result. [tcirviz](https://github.com/mikepapadim/tornadovm-tcirviz) shows how TC, TornadoVM's kernel compiler, gets there. It lays out the method at every step, from Java to bytecode, through TC's IR after every stage and pass, to the Metal, OpenCL or CUDA code. Click a Java line, a bytecode or an IR value and every pane highlights what came from it. It only compiles, so it needs no GPU and you can pick any of the three targets on any machine.

```bash
demos/L17-matmul-jit-aot/tcirviz.sh          # the UI on kernels/MatrixMultiplication.java, at http://127.0.0.1:7878/
demos/L17-matmul-jit-aot/tcirviz.sh app      # the UI on your own class from step 2: Open class… → MatrixMultiplication
demos/L17-matmul-jit-aot/tcirviz.sh print    # no browser: the generated kernel; [metal|opencl|cuda] [size] [method]
```

The first run clones tcirviz next to the script, at the commit pinned in [`env/versions.env`](../../env/versions.env), and builds it against the 8.1.0 SDK in a few seconds. [`kernels/MatrixMultiplication.java`](kernels/MatrixMultiplication.java) holds the exercise's method in three forms: `float[]` with `@Parallel`, the `FloatArray` version of the solution, and the Kernel API.

In the UI, set `size` to `1024` in the *Arguments* row. At run time, TornadoVM compiles a task for the arguments it runs with, and tcirviz does the same. Then step through the chips at the top (`←` / `→`):

| Stage | What happens to `matrixMultiplication` |
|---|---|
| **bytecode** | What `javac` made of it: three loops of `iload`/`imul`/`iadd` index arithmetic around `faload`, `fmul`, `fadd` and a `fastore`. |
| **input** | TC's IR, in SSA form. Loop variables become block arguments (`^bci24(%k.1: i32, %sum.1: f32)`), and the two `@Parallel` loops are marked `[parallel<iv = 0>]`. Array accesses are still Java-level: `%5 = array.load %a[%4] : f32`. |
| **specialise** | `size` becomes a constant: `%size.1 = const 1024 : i32`. Every loop bound is now known. |
| **parallel** | The `@Parallel` loops become the GPU grid. `i` starts at `tornado.thread_id.global<dim = 1>`, `j` at `<dim = 0>`, and each one steps by the grid size (`tornado.global_size`), with a guard against `int` overflow. TornadoVM launches one thread per `(i, j)`, so each thread runs one iteration. The loops stay so that a smaller grid would still cover the matrix. Only `k` remains a real loop. |
| **optimize** | `canonicalize` folds away `0 + thread_id`. `dce` deletes the dead start values. `licm` moves `i * size` out of the `j` and `k` loops, and `gvn` merges the two copies of it, one for `a` and one for `c`. Press **Δ** on a pass to see its diff. |
| **abi** | Arrays become pointers. `array.load %a[x]` becomes `load` at `a + 16 + 4·x`: the 16 bytes are the array header that TornadoVM keeps in front of the data on the device. |
| **optimize.post-abi** | `licm` again: the `a + 16` data pointers (`a_data`, `b_data`, `c_data`) move out of all three loops. |
| **structure** | The block graph becomes `loop`, `if` and `break`. It is still target-neutral. Press **⧉** for the control-flow graph, with the loop back-edges in orange. |
| **emit** | Metal, OpenCL C or CUDA C++. Each line of target code ends with a comment that names its Java line. |

**You should see** at the end, on Metal (`tcirviz.sh print`, the body of the kernel):

```c
  gid_x = (int) _thread_position_in_grid.x;  // MatrixMultiplication.java:18
  ...
  a_data = (device float *) (a + 16L);  // MatrixMultiplication.java:21
  b_data = (device float *) (b + 16L);  // MatrixMultiplication.java:21
  c_data = (device float *) (c + 16L);  // MatrixMultiplication.java:23
  i = (int) _thread_position_in_grid.y;
  for (; i < 1024; v36 = (long) i + v5, i = (int) (v36 > 2147483647L ? 2147483647L : v36)) {
    i_off = (int) ((uint) i * (uint) 1024);  // MatrixMultiplication.java:21
    j = gid_x;
    while (j < 1024) {
      k = 0;
      sum = 0.0f;
      while (k < 1024) {
        sum = sum + a_data[(int) ((uint) i_off + (uint) k)] * b_data[(int) ((uint) (int) ((uint) k * (uint) 1024) + (uint) j)];  // MatrixMultiplication.java:21
        k = k + 1;  // MatrixMultiplication.java:20
      }
      c_data[(int) ((uint) i_off + (uint) j)] = sum;  // MatrixMultiplication.java:23
      ...
```

This is the kernel the runtime installs. For your class at 1024, `tornado --printKernel` from step 3 prints the same code, line for line.

Try:

1. **Switch the target** to OpenCL or CUDA. The dot product becomes `fma(...)` (`fmaf` on CUDA). On Metal, TC leaves `sum + a * b` as it is, and the fusing is left to Metal's own compiler, which runs with fast math.
2. **Follow `sum`.** Click `sum +=` on the Java line. The *Journey* bar traces it from `fadd` in the IR to the line of Metal that uses it.
3. **Pick `matrixMultiplicationFloatArray`** in the kernel list. The GPU code is the same as for `float[]`: `get` and `set` become the same loads and stores.
4. **Clear `size`**, so it is not known when compiling. TC refuses the `@Parallel` kernel with `TC-E3103: the bounds of the @Parallel loops are not compile-time constants after specialisation, so no launch domain can be derived`. Then pick `matrixMultiplicationKernel`: it still compiles, with `while (k < size)` reading `size` at run time. With the Kernel API, the `WorkerGrid2D` you pass sets the launch grid, so TC does not need the bounds.

From the terminal: `tcirviz.sh print opencl`, `tcirviz.sh print metal "" matrixMultiplicationKernel`.

## Phase 2 · Ahead of time: Project Leyden and GraalVM native image

With JIT, every start pays for starting the JVM, loading and linking the TornadoVM runtime and its drivers, and warming up TC, TornadoVM's kernel compiler. That cost is the same for every run, and it dominates a short one. Two ways to pay most of it ahead of time:

| | What is stored ahead of time | Run with |
|---|---|---|
| **Project Leyden AOT cache** (JDK 25+, JEP 483/514/515) | the classes loaded and linked by a training run, resolved lambdas, and method profiles | the same JVM: `java -XX:AOTCache=matmul.aot …` |
| **GraalVM native image** | the whole application, TornadoVM runtime, drivers and TC compiled into one executable | no JVM: `./matmul` |

In both, the kernel is still compiled when the application runs: TC specialises it on the real arguments, as on the JVM. What moves ahead of time is the work around that compile.

`aot.sh` builds the jar, then starts the application all three ways with a short workload (256 × 256, one execution), one act per start, as L14 draws the Hybrid API. Each act times 5 starts and shows each one as it ends. The script ends with the three starts side by side, a bar each, and the checks:

```bash
demos/L17-matmul-jit-aot/aot.sh            # [jit|leyden|native|all] [size], default all 256
NO_PAUSE=1 demos/L17-matmul-jit-aot/aot.sh # no [enter] between acts; RUNS=n times n starts; NO_COLOR=1
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
