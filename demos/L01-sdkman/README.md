# L01 · SDKMAN!

Install the TornadoVM SDK in one line, run a built-in example, and generate the argfile that IDEs and build tools use to run TornadoVM.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once)

## Run

```bash
sdk list tornadovm              # the version grid: 7.1.0 × jdk21 / jdk22plus × opencl, cuda, metal
demos/L01-sdkman/run.sh         # devices, version, MatrixVectorRowMajor, then the argfile
```

## You should see

- `tornado --devices` lists your GPU as `Tornado device=0:0`. Pass that index to `-Dtornado.device` later.
- `MatrixVectorRowMajor` prints `Validation PASSED ✓`, then the speedup of each GPU version against plain Java. Get this far before moving on.
- The argfile ends with `--add-modules …,tornado.drivers.<backend>,…`.

## Notes

The example runs from the SDK's examples jar, the way you would run your own classes:

```bash
tornado -cp $TORNADOVM_HOME/share/java/tornado/tornado-examples-7.1.0.jar uk.ac.manchester.tornado.examples.compute.MatrixVectorRowMajor
```

Use the `jdk22plus` SDK unless you are pinned to JDK 21. After switching JDK, run `tornado --generate-argfile` again. A stale argfile fails with `Unrecognized VM option EnableJVMCI`.
