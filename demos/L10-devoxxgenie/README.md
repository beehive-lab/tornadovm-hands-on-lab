# L10 · DevoxxGenie: a local LLM inside your IDE

IntelliJ talks to jitLLM through its OpenAI-compatible endpoint, on your own GPU.

**Runs on:** every backend, with IntelliJ IDEA · **Needs:** L06's setup · **Plugin:** [stratika/DevoxxGenieIDEAPlugin](https://github.com/stratika/DevoxxGenieIDEAPlugin/tree/feature/jitllm-openai-server), branch `feature/jitllm-openai-server`

## Setup, once

The Marketplace build of DevoxxGenie does not have this branch, so build the fork (needs JDK 17+):

```bash
git clone -b feature/jitllm-openai-server https://github.com/stratika/DevoxxGenieIDEAPlugin.git demos/L10-devoxxgenie/DevoxxGenieIDEAPlugin
(cd demos/L10-devoxxgenie/DevoxxGenieIDEAPlugin && ./gradlew buildPlugin)
```

## Run

```bash
demos/L06-jitllm/jitllm.sh serve                  # terminal 1: leave it running, port 8090
curl -s localhost:8090/v1/models                  # terminal 2: shows "id":"gemma-4-E2B-it-Q4_0"
```

Then, in IntelliJ:

1. Open `Settings → Tools → DevoxxGenie`. Tick **jitLLM URL** and keep its URL, `http://localhost:8090/v1/`, the port `jitllm.sh serve` listens on.
2. On the same page, under "Large Language Model Response", tick **Enable Stream Mode**. Apply.
3. In the DevoxxGenie window, select the **jitLLM** provider and the model `gemma-4-E2B-it-Q4_0`.
4. Open a Java class in the editor and select it. Type `/explain` as the prompt and run it.

## You should see

- The explanation streams into the DevoxxGenie panel token by token, while terminal 1 logs the request.
- The model list offers `gemma-4-E2B-it-Q4_0`, the one model the server loaded.

## Notes

- DevoxxGenie shows token counts only with jitLLM's `feature/stream-usage` branch. That branch is not merged into `main` and builds against TornadoVM develop (`scripts/tornadovm-dev.sh` in the jitLLM repository), not the 7.1.0 SDK. Everything else works with the L06 build.
- Field labels move between plugin versions; check them on the day.
