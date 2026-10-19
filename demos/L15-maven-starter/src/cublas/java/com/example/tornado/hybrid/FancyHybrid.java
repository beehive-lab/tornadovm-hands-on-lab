/*
 * FancyHybrid: Java kernels and NVIDIA cuBLAS in one task graph (the "One task graph, two kinds of node" slide).
 *
 *   transferToDevice -> task "scale" (JIT) -> libraryTask "sgemv" (cuBLAS) -> task "bias" (JIT) -> transferToHost
 *
 * Read it in two halves, as on the slides: the TaskGraph says WHAT to run, the TornadoExecutionPlan says HOW.
 * Build with `mvn -Pcublas package`; run with a cuda TornadoVM SDK on an NVIDIA GPU:
 *   tornado -cp target/classes com.example.tornado.hybrid.FancyHybrid [m k executions]
 *
 * cuBLAS is column-major. A row-major M x K matrix is the column-major K x M matrix W^T, so
 * y = W · x is cuBLAS's y = op(A) · x with A = W^T, op = CUBLAS_OP_T: rows = K, columns = M, lda = K.
 */
package com.example.tornado.hybrid;

import uk.ac.manchester.tornado.api.GridScheduler;
import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.WorkerGrid1D;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.cublas.CuBlas;
import uk.ac.manchester.tornado.cublas.enums.CuBlasOperation;

public class FancyHybrid {

    public static void main(String[] args) throws TornadoExecutionPlanException {
        int m = args.length > 0 ? Integer.parseInt(args[0]) : 2048;
        int k = args.length > 1 ? Integer.parseInt(args[1]) : 4096;
        int executions = args.length > 2 ? Integer.parseInt(args[2]) : 5;

        DenseLayer layer = new DenseLayer(m, k);

        // WHAT to run: two Java kernels around one cuBLAS call, on shared device buffers
        TaskGraph taskGraph = new TaskGraph("hybrid") //
                .transferToDevice(DataTransferMode.FIRST_EXECUTION, layer.weights, layer.bias) // weights, constants: once
                .transferToDevice(DataTransferMode.EVERY_EXECUTION, layer.input) //               inputs that change: every run
                .task("scale", DenseLayer::scale, layer.input, layer.scaled) //
                .libraryTask("sgemv", CuBlas::cublasSgemv, //
                        CuBlasOperation.CUBLAS_OP_T.operation(), //
                        k, m, //                                   rows, columns of the column-major A = W^T
                        1.0f, layer.weights, k, //                 alpha, A, lda
                        layer.scaled, 1, //                        x, incx
                        0.0f, layer.output, 1) //                  beta, y, incy
                .task("bias", DenseLayer::biasRelu, layer.output, layer.bias) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, layer.output);

        // HOW to run it: the device, the launch grid of each Java kernel, and one CUDA graph for the whole chain
        GridScheduler grid = new GridScheduler();
        grid.addWorkerGrid("hybrid.scale", new WorkerGrid1D(k));
        grid.addWorkerGrid("hybrid.bias", new WorkerGrid1D(m));

        try (TornadoExecutionPlan plan = new TornadoExecutionPlan(taskGraph.snapshot())) {
            plan.withDevice(TornadoExecutionPlan.getDevice(0, 0)) // backend 0, device 0, as `tornado --devices` lists them
                    .withGridScheduler(grid) //
                    .withCUDAGraph(); //                             capture on the first execute(), replay after

            System.out.println("Device: " + TornadoExecutionPlan.getDevice(0, 0).getDescription());
            System.out.println("Dense layer " + m + " x " + k + ": Java scale -> cuBLAS sgemv -> Java bias");
            HybridRunner.run(plan, layer, executions);
        }
    }
}
