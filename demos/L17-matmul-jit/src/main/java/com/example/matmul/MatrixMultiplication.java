/*
 * L17 · Matrix multiplication in plain Java: the starting point of the exercise.
 *
 *   C = A · B, for square size × size matrices stored row by row in flat arrays
 *
 * No TornadoVM here yet. The exercise (README.md) turns matrixMultiplication into a GPU kernel:
 *   1. add tornado-api to pom.xml;
 *   2. parallelise the method with @Parallel or a KernelContext, checked as you type by TornadoInsight;
 *   3. run it with TornadoVM's JIT compiler from IntelliJ;
 *   4. look inside TC, the kernel compiler, with tcirviz; L18 then starts the result ahead of time.
 *
 * Run it: java -cp target/classes com.example.matmul.MatrixMultiplication [size] [iterations]
 */
package com.example.matmul;

import java.util.Random;

public class MatrixMultiplication {

    /** The method to accelerate: one output element per (i, j), a dot product over k. */
    public static void matrixMultiplication(float[] a, float[] b, float[] c, int size) {
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                float sum = 0.0f;
                for (int k = 0; k < size; k++) {
                    sum += a[i * size + k] * b[k * size + j];
                }
                c[i * size + j] = sum;
            }
        }
    }

    public static void main(String[] args) {
        int size = args.length > 0 ? Integer.parseInt(args[0]) : 1024;
        int iterations = args.length > 1 ? Integer.parseInt(args[1]) : 5;

        float[] a = new float[size * size];
        float[] b = new float[size * size];
        float[] c = new float[size * size];
        Random random = new Random(42);
        for (int i = 0; i < size * size; i++) {
            a[i] = random.nextFloat();
            b[i] = random.nextFloat();
        }

        System.out.println("Matrix multiplication, " + size + " x " + size + ", " + iterations + " executions, plain Java");
        double flop = 2.0 * size * size * size;
        for (int it = 0; it < iterations; it++) {
            long start = System.nanoTime();
            matrixMultiplication(a, b, c, size);
            long end = System.nanoTime();
            double ms = (end - start) / 1e6;
            System.out.printf("  execution %d: %8.2f ms  %7.2f GFLOP/s%n", it, ms, flop / (ms * 1e6));
        }
        System.out.printf("c[0] = %.4f, c[last] = %.4f%n", c[0], c[size * size - 1]);
    }
}
