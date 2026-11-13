/*
 * L18 · Matrix multiplication on the GPU, the finished TornadoVM application of L17, started ahead of time by aot.sh.
 *
 *   C = A · B, for square size × size matrices stored row by row in FloatArrays
 *
 * Loop Parallel API by default: @Parallel on the loops over i and j. The Kernel API is the third argument, kernel.
 * Every run checks the GPU result against the same method run by the JVM on the CPU, and prints Result is correct.
 *
 * Run it: demos/L18-matmul-aot/run.sh [size] [iterations] [kernel]
 */
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
