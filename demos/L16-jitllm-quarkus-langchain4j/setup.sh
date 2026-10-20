#!/usr/bin/env bash
# L16 · one-time setup: clones the Quarkus + LangChain4j demos, installs the unreleased jitllm provider
# of quarkus-langchain4j (pull request $QUARKUS_LC4J_PR) as 999-SNAPSHOT, and builds streaming-summarization.
# Steps already done are skipped. About 5 minutes the first time, most of it Maven downloads.
#   demos/L16-jitllm-quarkus-langchain4j/setup.sh
# Prints every command before it runs it.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

if [ ! -d "$JITLLM_QUARKUS_ROOT/.git" ]; then
  run git clone -b "$JITLLM_QUARKUS_REF" "$JITLLM_QUARKUS_REPO" "$JITLLM_QUARKUS_ROOT"
fi
run cd "$JITLLM_QUARKUS_ROOT"

# The jitllm provider is not in a quarkus-langchain4j release yet; the demos depend on 999-SNAPSHOT
PROVIDER="${MAVEN_REPO:-$HOME/.m2/repository}/io/quarkiverse/langchain4j/quarkus-langchain4j-jitllm-deployment/999-SNAPSHOT"
if [ -d "$PROVIDER" ]; then
  note "jitllm provider already installed: $PROVIDER"
else
  if [ ! -d quarkus-langchain4j/.git ]; then
    run git clone "$QUARKUS_LC4J_REPO" quarkus-langchain4j
  fi
  run git -C quarkus-langchain4j fetch origin "pull/$QUARKUS_LC4J_PR/head:jitllm-provider"
  run git -C quarkus-langchain4j checkout jitllm-provider
  run ./mvnw -q -f quarkus-langchain4j/pom.xml install -DskipTests -pl model-providers/jitllm/deployment -am
fi

# Quarkus runs its build step in a JVM with TornadoVM's flags; the argfile names this demo's SDK
if [ -f demos/streaming-summarization/target/quarkus-app/quarkus-run.jar ]; then
  note "streaming-summarization already built; delete $JITLLM_QUARKUS_ROOT/demos/streaming-summarization/target to build it again"
else
  run ./mvnw -q clean install -pl demos/streaming-summarization -am -Dtornado.argfile="$(scripts/tornado-args.sh)"
fi

echo "Ready. Next: $HERE/run.sh"
