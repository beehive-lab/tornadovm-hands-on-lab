/*
 * Java kernel + Apple MLX in one task graph: the Metal twin of CuBlasSgemvHybrid (L05).
 *
 * One TaskGraph, three stages, all on the same device buffers:
 *   1. JIT-compiled @Parallel task ("scale")  — Java kernel, compiled to Metal Shading Language
 *   2. MLX library task ("gemv")              — y = A · x, MLX's Metal kernel
 *   3. JIT-compiled @Parallel task ("bias")   — Java kernel, compiled to Metal Shading Language
 *
 * MLX is row-major, like the Java arrays, so A goes in as it is: no transpose flag as with cuBLAS.
 * A matrix-vector product is Mlx.matmul with N = 1: (M x K) · (K x 1).
 *
 * Every execution is checked against the same scale -> matvec -> bias pipeline in plain Java on the CPU.
 */
import uk.ac.manchester.tornado.api.ImmutableTaskGraph;
import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.TornadoExecutionResult;
import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;
import uk.ac.manchester.tornado.mlx.Mlx;

public class MlxSgemvHybrid {

    private static final float SCALE = 2.0f;
    private static final float BIAS = 1.0f;

    private static void scale(FloatArray matrix) {
        for (@Parallel int i = 0; i < matrix.getSize(); i++) {
            matrix.set(i, matrix.get(i) * SCALE);
        }
    }

    private static void bias(FloatArray output) {
        for (@Parallel int i = 0; i < output.getSize(); i++) {
            output.set(i, output.get(i) + BIAS);
        }
    }

    /** Deterministic, presenter-friendly fill: no RNG, same values every run. */
    private static void fillDeterministicMatrix(FloatArray matrix, int m, int n) {
        for (int i = 0; i < m * n; i++) {
            matrix.set(i, (i % 7) + 1.0f);
        }
    }

    private static void fillDeterministicVector(FloatArray vector, int n) {
        for (int j = 0; j < n; j++) {
            vector.set(j, (j % 5) + 1.0f);
        }
    }

    /** The whole pipeline, scale -> row-major matrix-vector product -> bias, on the CPU. */
    private static FloatArray expected(int m, int n) {
        FloatArray matrix = new FloatArray(m * n);
        FloatArray vector = new FloatArray(n);
        FloatArray output = new FloatArray(m);
        fillDeterministicMatrix(matrix, m, n);
        fillDeterministicVector(vector, n);
        for (int i = 0; i < m; i++) {
            float sum = 0.0f;
            for (int j = 0; j < n; j++) {
                sum += matrix.get(i * n + j) * SCALE * vector.get(j);
            }
            output.set(i, sum + BIAS);
        }
        return output;
    }

    public static void main(String[] args) throws TornadoExecutionPlanException {
        int m = args.length > 0 ? Integer.parseInt(args[0]) : 8;
        int n = args.length > 1 ? Integer.parseInt(args[1]) : 8;
        int iterations = args.length > 2 ? Integer.parseInt(args[2]) : 5;

        FloatArray matrix = new FloatArray(m * n);
        FloatArray vector = new FloatArray(n);
        FloatArray output = new FloatArray(m);
        FloatArray expected = expected(m, n);

        TaskGraph taskGraph = new TaskGraph("mlxHybrid") //
                .transferToDevice(DataTransferMode.EVERY_EXECUTION, matrix, vector) //
                .task("scale", MlxSgemvHybrid::scale, matrix) //
                .libraryTask("gemv", Mlx::matmul, matrix, vector, output, m, n, 1) //
                .task("bias", MlxSgemvHybrid::bias, output) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, output);

        ImmutableTaskGraph immutableTaskGraph = taskGraph.snapshot();
        boolean allCorrect = true;
        try (TornadoExecutionPlan plan = new TornadoExecutionPlan(immutableTaskGraph)) {
            for (int it = 0; it < iterations; it++) {
                // Reset host matrix/vector before every execution: EVERY_EXECUTION
                // re-copies them, and the "scale" task mutates the matrix in place on the device.
                fillDeterministicMatrix(matrix, m, n);
                fillDeterministicVector(vector, n);

                TornadoExecutionResult result = plan.execute();

                boolean correct = true;
                for (int i = 0; i < m; i++) {
                    float want = expected.get(i);
                    if (Math.abs(want - output.get(i)) > 1e-4f * Math.max(1.0f, Math.abs(want))) {
                        correct = false;
                        break;
                    }
                }
                allCorrect &= correct;
                System.out.println("iteration " + it + ": " + (correct ? "correct" : "WRONG") //
                        + " output[0]=" + output.get(0) + " expected[0]=" + expected.get(0));
                System.out.println("  total task-graph time: " + result.getProfilerResult().getTotalTime() + " ns");
            }
        }
        System.out.println(allCorrect ? "All iterations correct" : "SOME ITERATIONS WRONG");
    }
}
