# L10 · DevoxxGenie: a local LLM inside your IDE

IntelliJ talks to jitLLM over its OpenAI-compatible endpoint, on your own GPU.

| | |
|---|---|
| Platforms | macOS · Metal, Linux · CUDA, Linux · OpenCL, with IntelliJ IDEA |
| GPU memory | as L08: 14GB budget by default, see [GPU memory](../L08-jitllm/README.md#gpu-memory) |
| Engine | [beehive-lab/jitllm](https://github.com/beehive-lab/jitllm/tree/feature/stream-usage), branch `feature/stream-usage` |
| Plugin | [stratika/DevoxxGenieIDEAPlugin](https://github.com/stratika/DevoxxGenieIDEAPlugin/tree/feature/jitllm-openai-server), branch `feature/jitllm-openai-server` |
| Runtime | the TornadoVM build from L08 (the deck shows `7.0.1-jdk22plus-cuda`) |

## 1. Build and start the engine

```bash
git clone -b feature/stream-usage https://github.com/beehive-lab/jitllm.git && cd jitllm
# build as in L08 (scripts/tornadovm-dev.sh), then:
# on Metal, add --fp32-kv-cache: a source build refuses an FP16 key/value cache for F16 Llama (GPUL-CFG-002)
./jitllm serve -m beehive-llama-3.2-1b-instruct-fp16.gguf --gpu --gpu-memory 14GB --port 8090
```

## 2. Build and install the plugin

The Marketplace build of DevoxxGenie does not include this branch, so build the fork (JDK 17+, same steps on macOS and Linux):

```bash
git clone -b feature/jitllm-openai-server https://github.com/stratika/DevoxxGenieIDEAPlugin.git
cd DevoxxGenieIDEAPlugin
./gradlew buildPlugin          # produces build/distributions/DevoxxGenie-X.Y.Z.zip
```

In IntelliJ: `Settings → Plugins → ⚙ → Install Plugin from Disk`, pick the zip, and restart.

## 3. Wire it up

In the DevoxxGenie settings, choose provider **Custom OpenAI**, base URL `http://localhost:8090/v1`, and any non-empty API key. Then select a method, ask for a test, and watch jitLLM stream the answer.

Field labels move between plugin versions; check them on the day.

**Known issue:** building `feature/stream-usage` from source needs TornadoVM develop artifacts (see L08), while the slide pairs it with the 7.0.1 SDK. Confirm the pairing before the session.
