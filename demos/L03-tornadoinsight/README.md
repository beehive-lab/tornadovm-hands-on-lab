# L03 · Debug with TornadoInsight

Catch unsupported Java as you type, and run one task from the IDE without writing a `main` method or a `TaskGraph`.

**Runs on:** every backend, in IntelliJ IDEA · **Needs:** [Setup once](../../README.md#setup-once) · **Code:** the plugin is [beehive-lab/tornado-insight](https://github.com/beehive-lab/tornado-insight); the kernel is [`RecursionExample.java`](uk/ac/manchester/tornado/examples/tornadoinsight/RecursionExample.java), in this folder

## Setup

1. Install **TornadoInsight** from the [JetBrains Marketplace](https://plugins.jetbrains.com/plugin/23309-tornadoinsight) and restart IntelliJ.
2. Open `Settings → TornadoInsight`. Set the TornadoVM root to your SDK (`echo $TORNADOVM_HOME`), the JDK to 21 or newer, and any array size. The [configuration guide](https://www.tornadovm.org/blogs/tornadoinsight-compatibility-with-tornadovm-sdk-2-0-configuration-guide) covers SDKs installed with SDKMAN!.
3. `File → Open…`, pick `demos/L03-tornadoinsight/pom.xml`, then choose `Open as Project`.

## Run

1. Open `RecursionExample.java`. In `broken`, the checker flags the `String`, the `throw` and the recursion, and the TornadoInsight panel does not list `broken`.
2. In the TornadoInsight window, select `fixed` and run it. The plugin generates the `main` method and the `TaskGraph`, runs the task and prints the kernel.

To run it from the command line instead:

```bash
(cd demos/L03-tornadoinsight && ./mvnw -q compile && \
 tornado --printKernel -cp target/classes uk.ac.manchester.tornado.examples.tornadoinsight.RecursionExample 1024)
```

## You should see

- The editor marks the unsupported lines in `broken` as you type.
- The command line run ends with `Result is correct for 1024 elements.`

## Notes

- `fixed` does the same calculation as `broken`, with no `String` and no `throw` (negative inputs map to 0), and a loop in place of the recursion.
- Keep the class in its `uk.ac.manchester.tornado.*` package. TornadoInsight treats a kernel's call into a class outside `java.*` and `uk.ac.manchester.tornado.*` as an external library call, and hides that kernel.
- If imports show `Cannot resolve symbol 'Parallel'`, the project was not opened from `pom.xml`.
