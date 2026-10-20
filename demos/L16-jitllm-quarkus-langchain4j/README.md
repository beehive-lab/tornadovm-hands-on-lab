# L16 · jitLLM in a Quarkus app, through LangChain4j

A Quarkus application declares an AI service with LangChain4j, `@RegisterAiService` on an interface, and gets its answers from jitLLM on your GPU: no Python, no server, no API key. It summarizes an article about electric vehicles and streams the summary token by token as a Mutiny `Multi<String>`.

**Runs on:** every backend · **Needs:** [Setup once](../../README.md#setup-once), JDK 25 and TornadoVM 7.3.1 · **GPU memory:** 8GB · **Code:** [beehive-lab/JitLLM-Quarkus-Langchain4j-Demo](https://github.com/beehive-lab/JitLLM-Quarkus-Langchain4j-Demo), module `demos/streaming-summarization` · **Model:** [Llama 3.2 1B instruct, F16](https://huggingface.co/unsloth/Llama-3.2-1B-Instruct-GGUF), 2.5GB

## Setup, once

jitLLM 1.0.2, which the Quarkus extension uses, needs TornadoVM 7.2 or newer, so this demo runs on its own 7.3.1 SDK:

```bash
sdk install tornadovm 7.3.1-jdk22plus-metal      # macOS;  or -cuda (NVIDIA), -opencl (Intel, AMD)
                                                 # answer n to making it the default
demos/L16-jitllm-quarkus-langchain4j/setup.sh
```

`setup.sh` clones the demos repository into `demos/L16-jitllm-quarkus-langchain4j/JitLLM-Quarkus-Langchain4j-Demo` and builds `streaming-summarization` with its Maven wrapper. The `jitllm` provider of quarkus-langchain4j is not released yet ([quarkiverse/quarkus-langchain4j#2888](https://github.com/quarkiverse/quarkus-langchain4j/pull/2888)), so the script first builds that pull request and installs it in `~/.m2` as `999-SNAPSHOT`, which takes a few minutes. Run it again at any time: it skips the steps already done.

## Run

```bash
demos/L16-jitllm-quarkus-langchain4j/run.sh
```

It runs, from the clone:

```bash
java @<argfile for the 7.3.1 SDK> --add-modules jdk.incubator.vector -jar demos/streaming-summarization/target/quarkus-app/quarkus-run.jar
```

The first run downloads the model to `~/.langchain4j/models/`. After that it takes about 10 seconds.

## You should see

- The Quarkus banner, then the article.
- `Streaming Summary:`, then the summary arriving a few tokens at a time: `ONE SENTENCE SUMMARY`, `MAIN POINTS`, `TAKEAWAYS`.
- The same summary again, after `[LLM response]`: the extension logs the full response once it is complete.
- `--- Streaming Complete ---`.

## The code

The whole AI service is an interface; Quarkus generates the implementation and wires in jitLLM:

```java
@RegisterAiService
@ApplicationScoped
@SystemMessage("You are an expert content summarizer. ...")
public interface SummarizationStreamingService {
    @UserMessage("Input: {input}")
    Multi<String> summarize(String input);
}
```

The model, its quantization and the GPU memory are in [`application.properties`](https://github.com/beehive-lab/JitLLM-Quarkus-Langchain4j-Demo/blob/main/demos/streaming-summarization/src/main/resources/application.properties):

```properties
quarkus.langchain4j.jitllm.chat-model.model-name=unsloth/Llama-3.2-1B-Instruct-GGUF
quarkus.langchain4j.jitllm.chat-model.quantization=F16
quarkus.langchain4j.jitllm.chat-model.device-memory=8GB
```

## Notes

- **Your own clone:** set `JITLLM_QUARKUS_ROOT` to it, for `setup.sh` and `run.sh`.
- **GPU memory:** the extension sets TornadoVM's device memory from `device-memory`, so `TORNADO_DEVICE_MEMORY` has no effect here. To change it for one run, add `-Dquarkus.langchain4j.jitllm.chat-model.device-memory=6GB` to the `java` command.
- **Model:** the model name and quantization are fixed when Quarkus builds the app. Change them in `application.properties`, then delete the module's `target` folder and run `setup.sh` again.
- **On TornadoVM 7.1.0** the first generation fails: `Unable to resolve method HalfFloatArray.getHalf4`. jitLLM 1.0.2 needs 7.2 or newer.
- **A failed generation** is logged and the app still exits with 0, so `run.sh` fails when the log shows `Error in JitLLM` or an exception.
- **More demos:** the repository also has tool calling, code generation and a pull-request reviewer; see [its README](https://github.com/beehive-lab/JitLLM-Quarkus-Langchain4j-Demo).
