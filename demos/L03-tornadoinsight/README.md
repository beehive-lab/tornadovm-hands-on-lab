# L03 · Debug with TornadoInsight

Catch unsupported Java as you type, and run one task from the IDE with no `main` and no `TaskGraph`.

| | |
|---|---|
| Platforms | macOS and Linux, any backend, IntelliJ IDEA |
| GPU memory | set by the array size you configure; small by default |
| Code | the plugin lives in [beehive-lab/tornado-insight](https://github.com/beehive-lab/tornado-insight); the faulty kernel is [`Broken.java`](Broken.java) in this repo |
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

## Run

1. Open [`Broken.java`](Broken.java). The static checker flags the `String`, the `throw` and the recursion as you type.
2. Select the method in the TornadoInsight window to run it. The plugin generates the `main` method and the `TaskGraph`, runs the task on your local TornadoVM, and prints the generated kernel.

The static checker also covers native method calls and `assert` statements. Dynamic inspection does not follow calls into non-JDK methods.
