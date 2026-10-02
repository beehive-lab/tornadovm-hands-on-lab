# L03 · Debug with TornadoInsight

Catch unsupported Java as you type, and run one task from the IDE with no `main` and no `TaskGraph`.

| | |
|---|---|
| Platforms | macOS and Linux, any backend, IntelliJ IDEA |
| GPU memory | set by the array size you configure; small by default |
| Code | the plugin lives in [beehive-lab/tornado-insight](https://github.com/beehive-lab/tornado-insight); the kernel, broken and fixed, is [`RecursionExample.java`](uk/ac/manchester/tornado/examples/tornadoinsight/RecursionExample.java) in this repo |
| Requires | TornadoVM ≥ 1.0, JDK ≥ 21 |

## Install the plugin

Either from the [JetBrains Marketplace](https://plugins.jetbrains.com/plugin/23309-tornadoinsight), or from source, as the plugin README describes:

```bash
git clone https://github.com/beehive-lab/tornado-insight.git && cd tornado-insight
sh gradlew clean build          # the plugin zip lands in build/distributions/
```

Then in IntelliJ: `Help → Find Action… → Install plugin from disk`, pick the zip, and restart.

## Configure

`Settings → TornadoInsight`: set the TornadoVM root directory, a JDK ≥ 21, and an array size for test inputs.

To point the plugin at a TornadoVM SDK installed with SDKMAN!, follow [TornadoInsight compatibility with TornadoVM SDK 2.0: configuration guide](https://www.tornadovm.org/blogs/tornadoinsight-compatibility-with-tornadovm-sdk-2-0-configuration-guide).

## Open the demo

In IntelliJ, open [`pom.xml`](pom.xml) in this folder as a project (`File → Open…`, pick the file, `Open as Project`), or right-click it in an open project and choose `Add as Maven Project`. It adds `tornado-api` from Maven Central, so the editor resolves `uk.ac.manchester.tornado.api.*`; without it, the classes show `Cannot resolve symbol 'Parallel'`. The pom uses Java 22, matching the `jdk22plus` SDK.

## Run

1. Open [`RecursionExample.java`](uk/ac/manchester/tornado/examples/tornadoinsight/RecursionExample.java). In `broken`, the static checker flags the `String`, the `throw` and the recursion as you type, and TornadoInsight leaves `broken` out of its task panel.
2. Select `fixed` in the TornadoInsight window to run it. `fixed` does the same calculation with no `String`, no `throw` (negative inputs map to 0) and a loop in place of the recursion. The plugin generates the `main` method and the `TaskGraph`, runs the task on your local TornadoVM, and prints the generated kernel.

### From the command line

The class's own `main` runs `fixed` and checks the GPU result against plain Java:

```bash
mvn -q compile
tornado --printKernel -cp target/classes uk.ac.manchester.tornado.examples.tornadoinsight.RecursionExample 1024
# ends with: Result is correct for 1024 elements.
```

Keep the class in its `uk.ac.manchester.tornado.*` package. TornadoInsight treats a call from a kernel into any class outside `java.*` and `uk.ac.manchester.tornado.*` as an external library call, and leaves that kernel out of the task panel. Without the package, `fixed` calls `halvings` in such a class and does not appear there.

The static checker also covers native method calls and `assert` statements. Dynamic inspection does not follow calls into non-JDK methods.
