# L02 · Run on the GPU, then look inside

The L01 example again, plus two flags: one shows the code the JIT generated, the other the steps the runtime takes. The slide shows Metal, but every backend works. Backup demo: its slide is hidden in the current deck.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once)

## Run

```bash
demos/L02-metal-look-inside/run.sh    # VectorAddInt, then --printKernel, then --printBytecodes
```

## You should see

- `--printKernel`: the generated source, which is Metal Shading Language on a Mac, `extern "C" __global__ void vectorAdd(…)` on CUDA, and OpenCL C on OpenCL.
- `--printBytecodes`: one `bc:` line per runtime step, in the order `ALLOC`, `TRANSFER_HOST_TO_DEVICE_…`, `LAUNCH task s0.t0 - vectorAdd`, `TRANSFER_DEVICE_TO_HOST_…`, `DEALLOC`. These are the steps from the TaskGraph animation, and `withCUDAGraph()` captures and replays at this level.
