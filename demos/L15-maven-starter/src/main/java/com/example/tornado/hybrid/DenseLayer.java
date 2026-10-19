/*
 * Step 2: a dense neural-network layer, y = relu(W · x/255 + b), split between
 * Java kernels and a vendor library in one task graph:
 *
 *   1. task "scale"         Java kernel     xs = x / 255
 *   2. libraryTask "sgemv"  library         y  = W · xs      CuBlas::cublasSgemv (FancyHybrid) or Mlx::matmul (FancyHybridMlx)
 *   3. task "bias"          Java kernel     y  = max(y + b, 0)
 *
 * The three tasks share device buffers: xs and y never come back to the host between tasks.
 * This class holds what both versions share: the two Java kernels, the data and the CPU check.
 * It needs only tornado-api, so it is in the default build.
 */
package com.example.tornado.hybrid;

import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;

public final class DenseLayer {

    /** Output neurons (rows of W) and inputs (columns of W). W is row-major, M x K. */
    public final int m;
    public final int k;

    public final FloatArray weights;
    public final FloatArray bias;
    public final FloatArray input;
    public final FloatArray scaled;
    public final FloatArray output;

    public DenseLayer(int m, int k) {
        this.m = m;
        this.k = k;
        weights = new FloatArray(m * k);
        bias = new FloatArray(m);
        input = new FloatArray(k);
        scaled = new FloatArray(k);
        output = new FloatArray(m);
        // deterministic values, no RNG: the same numbers every run; some sums go negative, so ReLU clips them
        for (int i = 0; i < m * k; i++) {
            weights.set(i, ((i % 7) - 3) * 0.01f);
        }
        for (int i = 0; i < m; i++) {
            bias.set(i, (i % 3) * 0.1f - 0.1f);
        }
        fillInput(0);
    }

    /** A new input for every execution, a "pixel" in 0..255, so each run (and each CUDA-graph replay) is checked on fresh data. */
    public void fillInput(int execution) {
        for (int j = 0; j < k; j++) {
            input.set(j, (j + 31 * execution) % 256);
        }
    }

    // Kernel names must not be GPU built-ins: a method called "normalize" fails with
    // "Java method name corresponds to an OpenCL Token".
    public static void scale(FloatArray input, FloatArray scaled) {
        for (@Parallel int i = 0; i < input.getSize(); i++) {
            scaled.set(i, input.get(i) / 255.0f);
        }
    }

    public static void biasRelu(FloatArray output, FloatArray bias) {
        for (@Parallel int i = 0; i < output.getSize(); i++) {
            output.set(i, Math.max(output.get(i) + bias.get(i), 0.0f));
        }
    }

    /** The whole layer in plain Java on the CPU, for the current input. */
    public FloatArray expected() {
        FloatArray xs = new FloatArray(k);
        FloatArray y = new FloatArray(m);
        scale(input, xs);
        for (int i = 0; i < m; i++) {
            float sum = 0.0f;
            for (int j = 0; j < k; j++) {
                sum += weights.get(i * k + j) * xs.get(j);
            }
            y.set(i, sum);
        }
        biasRelu(y, bias);
        return y;
    }

    /** "correct", or where the GPU output first differs from the CPU. */
    public String check(FloatArray expected) {
        for (int i = 0; i < m; i++) {
            float want = expected.get(i);
            if (Math.abs(want - output.get(i)) > 1e-3f * Math.max(1.0f, Math.abs(want))) {
                return "WRONG at " + i + ": " + output.get(i) + " != " + want;
            }
        }
        return "correct";
    }
}
