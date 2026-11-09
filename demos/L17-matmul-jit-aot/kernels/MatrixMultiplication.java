/*
 * L17 · the matrix multiplication of the exercise, for tcirviz (tcirviz.sh), in the three forms the lab uses.
 * tcirviz compiles this file with TC, TornadoVM's kernel compiler, and shows every stage from bytecode to GPU code.
 * It is not part of the Maven build: tcirviz.sh passes it to tcirviz, which compiles it with its own javac.
 *
 *   matrixMultiplication            float[] and @Parallel: the method of the exercise, step 2
 *   matrixMultiplicationFloatArray  the same with FloatArray, as in the solution: the GPU code is the same
 *   matrixMultiplicationKernel      Kernel API: one GPU thread per (i, j), the loops over i and j are gone
 */
import uk.ac.manchester.tornado.api.KernelContext;
import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;

public class MatrixMultiplication {

    public static void matrixMultiplication(float[] a, float[] b, float[] c, int size) {
        for (@Parallel int i = 0; i < size; i++) {
            for (@Parallel int j = 0; j < size; j++) {
                float sum = 0.0f;
                for (int k = 0; k < size; k++) {
                    sum += a[i * size + k] * b[k * size + j];
                }
                c[i * size + j] = sum;
            }
        }
    }

    public static void matrixMultiplicationFloatArray(FloatArray a, FloatArray b, FloatArray c, int size) {
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

    public static void matrixMultiplicationKernel(KernelContext context, float[] a, float[] b, float[] c, int size) {
        int i = context.globalIdx;
        int j = context.globalIdy;
        float sum = 0.0f;
        for (int k = 0; k < size; k++) {
            sum += a[i * size + k] * b[k * size + j];
        }
        c[i * size + j] = sum;
    }
}
