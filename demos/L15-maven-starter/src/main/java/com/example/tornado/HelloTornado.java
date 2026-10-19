/*
 * Step 1: one Java method, JIT-compiled by TornadoVM for the GPU.
 *
 *   c[i] = a[i] + b[i]
 *
 * The loop marked @Parallel becomes the GPU's thread index; everything else is plain Java.
 * The TaskGraph says what runs and which data moves; the TornadoExecutionPlan runs it.
 * The result is checked against the same loop on the CPU.
 */
package com.example.tornado;

import uk.ac.manchester.tornado.api.ImmutableTaskGraph;
import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;

public class HelloTornado {

    /** The kernel: TornadoVM compiles this method, not the JVM. */
    public static void vectorAdd(FloatArray a, FloatArray b, FloatArray c) {
        for (@Parallel int i = 0; i < c.getSize(); i++) {
            c.set(i, a.get(i) + b.get(i));
        }
    }

    public static void main(String[] args) throws TornadoExecutionPlanException {
        int size = args.length > 0 ? Integer.parseInt(args[0]) : 1 << 24;
        int iterations = args.length > 1 ? Integer.parseInt(args[1]) : 10;

        // FloatArray lives off-heap, so TornadoVM can hand it to the GPU without copying it first
        FloatArray a = new FloatArray(size);
        FloatArray b = new FloatArray(size);
        FloatArray c = new FloatArray(size);
        for (int i = 0; i < size; i++) {
            a.set(i, i);
            b.set(i, 2.0f * i);
        }

        TaskGraph taskGraph = new TaskGraph("hello") //
                .transferToDevice(DataTransferMode.FIRST_EXECUTION, a, b) //
                .task("vectorAdd", HelloTornado::vectorAdd, a, b, c) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, c);
        ImmutableTaskGraph immutableTaskGraph = taskGraph.snapshot();

        System.out.println("Device: " + TornadoExecutionPlan.getDevice(0, 0).getDescription());
        System.out.println("vectorAdd of " + size + " floats, " + iterations + " executions");

        try (TornadoExecutionPlan plan = new TornadoExecutionPlan(immutableTaskGraph)) {
            for (int it = 0; it < iterations; it++) {
                long start = System.nanoTime();
                plan.execute();
                long elapsed = System.nanoTime() - start;
                // the first execution includes the JIT compilation of vectorAdd
                System.out.printf("  execution %2d: %8.3f ms%s%n", it, elapsed / 1e6, it == 0 ? "  (JIT compile + run)" : "");
            }
        }

        FloatArray expected = new FloatArray(size);
        vectorAdd(a, b, expected); // the same method, run by the JVM on the CPU
        for (int i = 0; i < size; i++) {
            if (c.get(i) != expected.get(i)) {
                System.out.println("WRONG at " + i + ": " + c.get(i) + " != " + expected.get(i));
                System.exit(1);
            }
        }
        System.out.println("Result is correct for " + size + " elements");
    }
}
