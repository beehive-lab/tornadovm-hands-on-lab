package com.example.tornado.hybrid;

import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;

/** Runs a FancyHybrid plan with a new input each time, timing every execution and checking it against the CPU. */
final class HybridRunner {

    private HybridRunner() {
    }

    static void run(TornadoExecutionPlan plan, DenseLayer layer, int executions) {
        boolean allCorrect = true;
        for (int it = 0; it < executions; it++) {
            layer.fillInput(it);
            FloatArray expected = layer.expected();
            long start = System.nanoTime();
            plan.execute();
            long elapsed = System.nanoTime() - start;
            String check = layer.check(expected);
            allCorrect &= check.equals("correct");
            System.out.printf("  execution %d: %8.3f ms  %s%s%n", it, elapsed / 1e6, check, it == 0 ? "  (JIT compile + run)" : "");
        }
        System.out.println(allCorrect ? "All executions correct" : "SOME EXECUTIONS WRONG");
        if (!allCorrect) {
            System.exit(1);
        }
    }
}
