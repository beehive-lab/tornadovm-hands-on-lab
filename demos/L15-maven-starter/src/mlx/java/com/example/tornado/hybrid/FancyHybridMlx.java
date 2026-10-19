/*
 * FancyHybridMlx: the Apple Silicon twin of FancyHybrid. Same Java kernels, same plan; Mlx::matmul in place of cuBLAS.
 *
 *   transferToDevice -> task "scale" (JIT) -> libraryTask "gemv" (MLX) -> task "bias" (JIT) -> transferToHost
 *
 * Build with `mvn -Pmlx package`; run with a metal TornadoVM SDK, 7.3.0 or newer:
 *   tornado -cp target/classes com.example.tornado.hybrid.FancyHybridMlx [m k executions]
 *
 * MLX is row-major, like the Java arrays, so W goes in as it is.
 * Mlx.matmul(a, b, c, M, K, N) computes c = a · b for a M x K and b K x N: a matrix-vector product is N = 1.
 */
package com.example.tornado.hybrid;

import uk.ac.manchester.tornado.api.GridScheduler;
import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.WorkerGrid1D;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.mlx.Mlx;

public class FancyHybridMlx {

    public static void main(String[] args) throws TornadoExecutionPlanException {
        int m = args.length > 0 ? Integer.parseInt(args[0]) : 2048;
        int k = args.length > 1 ? Integer.parseInt(args[1]) : 4096;
        int executions = args.length > 2 ? Integer.parseInt(args[2]) : 5;

        DenseLayer layer = new DenseLayer(m, k);

        // WHAT to run: two Java kernels around one MLX call, on shared device buffers
        TaskGraph taskGraph = new TaskGraph("hybrid") //
                .transferToDevice(DataTransferMode.FIRST_EXECUTION, layer.weights, layer.bias) // weights, constants: once
                .transferToDevice(DataTransferMode.EVERY_EXECUTION, layer.input) //               inputs that change: every run
                .task("scale", DenseLayer::scale, layer.input, layer.scaled) //
                .libraryTask("gemv", Mlx::matmul, layer.weights, layer.scaled, layer.output, m, k, 1) //
                .task("bias", DenseLayer::biasRelu, layer.output, layer.bias) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, layer.output);

        // HOW to run it: the plan of FancyHybrid without withCUDAGraph(). Metal has no execution graphs, and in
        // TornadoVM 7.3.1 withCUDAGraph() fails there ("does not support execution graphs") instead of being skipped.
        GridScheduler grid = new GridScheduler();
        grid.addWorkerGrid("hybrid.scale", new WorkerGrid1D(k));
        grid.addWorkerGrid("hybrid.bias", new WorkerGrid1D(m));

        try (TornadoExecutionPlan plan = new TornadoExecutionPlan(taskGraph.snapshot())) {
            plan.withDevice(TornadoExecutionPlan.getDevice(0, 0)) //
                    .withGridScheduler(grid);

            System.out.println("Device: " + TornadoExecutionPlan.getDevice(0, 0).getDescription());
            System.out.println("Dense layer " + m + " x " + k + ": Java scale -> MLX gemv -> Java bias");
            HybridRunner.run(plan, layer, executions);
        }
    }
}
