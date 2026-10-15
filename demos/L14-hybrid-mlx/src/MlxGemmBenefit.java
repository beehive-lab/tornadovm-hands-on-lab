/*
 * Why call a library: one SGEMM, C = A · B (N x N, row-major), two ways inside TornadoVM on the same GPU.
 *   java  a @Parallel Java kernel, JIT-compiled to Metal Shading Language
 *   mlx   Mlx::matmul, a library task: MLX's tuned Metal GEMM
 *
 * Usage: MlxGemmBenefit [N] [executions]
 * Each plan runs `executions` times. The first run includes JIT compilation (java) or MLX's
 * setup (mlx); the summary is the median wall clock of the rest, copy-out of C included.
 * Every execution is checked against plain Java on the CPU, on 16 rows spread over C.
 */
import java.util.Arrays;

import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;
import uk.ac.manchester.tornado.mlx.Mlx;

public class MlxGemmBenefit {

    private static final int CHECKED_ROWS = 16;

    private static void matmul(FloatArray a, FloatArray b, FloatArray c, int n) {
        for (@Parallel int i = 0; i < n; i++) {
            for (@Parallel int j = 0; j < n; j++) {
                float sum = 0.0f;
                for (int k = 0; k < n; k++) {
                    sum += a.get(i * n + k) * b.get(k * n + j);
                }
                c.set(i * n + j, sum);
            }
        }
    }

    /** Deterministic values in [-1, 1): same matrices every run. */
    private static void fill(FloatArray array, int seed) {
        for (int i = 0; i < array.getSize(); i++) {
            array.set(i, ((i * 31 + seed) % 97) / 48.5f - 1.0f);
        }
    }

    /** Rows of C computed on the CPU, for the checks. */
    private static float[][] expectedRows(FloatArray a, FloatArray b, int n, int[] rows) {
        float[][] expected = new float[rows.length][n];
        for (int r = 0; r < rows.length; r++) {
            for (int k = 0; k < n; k++) {
                float aik = a.get(rows[r] * n + k);
                for (int j = 0; j < n; j++) {
                    expected[r][j] += aik * b.get(k * n + j);
                }
            }
        }
        return expected;
    }

    private static boolean matches(FloatArray c, float[][] expected, int n, int[] rows) {
        for (int r = 0; r < rows.length; r++) {
            for (int j = 0; j < n; j++) {
                float want = expected[r][j];
                if (Math.abs(want - c.get(rows[r] * n + j)) > 1e-3f * Math.max(1.0f, Math.abs(want))) {
                    return false;
                }
            }
        }
        return true;
    }

    /** Runs the plan `executions` times; returns {first, median of the rest} in microseconds. */
    private static long[] measure(String label, TaskGraph graph, FloatArray c, float[][] expected, int n, int[] rows, int executions)
            throws TornadoExecutionPlanException {
        long[] times = new long[executions];
        boolean allCorrect = true;
        try (TornadoExecutionPlan plan = new TornadoExecutionPlan(graph.snapshot())) {
            for (int e = 0; e < executions; e++) {
                c.init(0.0f);
                long start = System.nanoTime();
                plan.execute();
                times[e] = (System.nanoTime() - start) / 1000;
                allCorrect &= matches(c, expected, n, rows);
            }
        }
        long[] steady = Arrays.copyOfRange(times, 1, executions);
        Arrays.sort(steady);
        long median = steady[steady.length / 2];
        System.out.printf("%s: first execution %d us, steady-state median %d us%n", label, times[0], median);
        System.out.println(label + ": " + (allCorrect ? "All executions correct" : "SOME EXECUTIONS WRONG"));
        return new long[] { times[0], median };
    }

    public static void main(String[] args) throws TornadoExecutionPlanException {
        int n = args.length > 0 ? Integer.parseInt(args[0]) : 2048;
        int executions = Math.max(2, args.length > 1 ? Integer.parseInt(args[1]) : 20);

        FloatArray a = new FloatArray(n * n);
        FloatArray b = new FloatArray(n * n);
        FloatArray cJava = new FloatArray(n * n);
        FloatArray cMlx = new FloatArray(n * n);
        fill(a, 1);
        fill(b, 2);

        int[] rows = new int[CHECKED_ROWS];
        for (int r = 0; r < CHECKED_ROWS; r++) {
            rows[r] = (int) ((long) r * (n - 1) / (CHECKED_ROWS - 1));
        }
        float[][] expected = expectedRows(a, b, n, rows);

        TaskGraph javaGraph = new TaskGraph("java") //
                .transferToDevice(DataTransferMode.FIRST_EXECUTION, a, b) //
                .task("matmul", MlxGemmBenefit::matmul, a, b, cJava, n) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, cJava);

        TaskGraph mlxGraph = new TaskGraph("mlx") //
                .transferToDevice(DataTransferMode.FIRST_EXECUTION, a, b) //
                .libraryTask("matmul", Mlx::matmul, a, b, cMlx, n, n, n) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, cMlx);

        System.out.printf("SGEMM %d x %d x %d, %d executions per plan%n", n, n, n, executions);
        long[] java = measure("java kernel", javaGraph, cJava, expected, n, rows, executions);
        long[] mlx = measure("Mlx::matmul", mlxGraph, cMlx, expected, n, rows, executions);

        double flops = 2.0 * n * n * n;
        System.out.printf("steady-state: java=%d us, mlx=%d us, speedup=%.1fx, java=%.0f GFLOP/s, mlx=%.0f GFLOP/s%n", //
                java[1], mlx[1], (double) java[1] / mlx[1], flops / java[1] / 1e3, flops / mlx[1] / 1e3);
    }
}
