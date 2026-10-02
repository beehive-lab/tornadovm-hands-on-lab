# L02 · Run on Metal, then look inside

The same example on your SDK (Metal on the Mac in the session), plus the two flags that show what the JIT generated and what the runtime does.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL (prints MSL, CUDA C or OpenCL C) |
| GPU memory | under 100 MB; the TornadoVM default (4GB) is plenty |
| Code | in this repo: [`run.sh`](run.sh), using the SDK's built-in `tornado.examples` |
| Note | backup demo: its slide is hidden in the current deck |

## Run

```bash
./run.sh
```

## What to look for

- `--printKernel` prints the generated source: Metal Shading Language on the Mac, CUDA C or OpenCL C on other SDKs.
- `--printBytecodes` lists the runtime steps: `ALLOC`, the transfers, `LAUNCH`, `DEALLOC`. These are the steps the TaskGraph animation showed, and the level at which `withCUDAGraph()` captures and replays.
