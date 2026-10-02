#!/usr/bin/env bash
# Checks that every scripted demo runs on this machine: PASS / SKIP / FAIL per demo.
# A setup check before the session, not a benchmark. Logs go to logs/<date>/.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/env/versions.env"
OUT="$ROOT/logs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

printf '%-26s %s\n' "demo" "result"
for script in "$ROOT"/demos/L*/run.sh; do
  name="$(basename "$(dirname "$script")")"
  "$script" > "$OUT/$name.log" 2>&1
  case $? in
    0) result=PASS ;;
    3) result="SKIP  $(grep -m1 '^SKIP:' "$OUT/$name.log" | cut -c7-)" ;;
    *) result="FAIL  (see $OUT/$name.log)" ;;
  esac
  printf '%-26s %s\n' "$name" "$result"
done
echo "logs: $OUT"
