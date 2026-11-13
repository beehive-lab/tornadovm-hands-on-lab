#!/usr/bin/env python3
"""Terminal rendering for L17's aot.sh: a banner, act headers, pipelines, the starts of each act, and the comparison
of the three starts as a bar chart and a scoreboard. Standard library only. NO_COLOR=1 disables colors.
The same look as L14's fancy.py (and devoxx/fancy.py in the CUDA demos repository, L04, L05).

    fancy.py banner   TITLE SUBTITLE
    fancy.py act      N TITLE SUBTITLE
    fancy.py pipeline NAME:KIND ...          boxes joined by arrows
    fancy.py starts   STARTS MODE            the median of MODE's starts, from the STARTS table aot.sh writes
    fancy.py compare  STARTS CHECKS TITLE    every mode as a bar, the speed-up over jit, then the checks

STARTS has one row per timed start: mode, wall time in ms, the first execute() in ms (from the program's output),
PASS or FAIL. CHECKS has one row per check: PASS, FAIL or SKIP, then its text.
"""
import os
import re
import statistics
import sys

COLOR = os.environ.get("NO_COLOR") is None
WIDTH = 44

RESET, BOLD, DIM = "\033[0m", "\033[1m", "\033[2m"
GREEN, YELLOW, CYAN, MAGENTA, BLUE, RED, WHITE = (
    "\033[1;32m", "\033[1;33m", "\033[1;36m", "\033[1;35m", "\033[1;34m", "\033[1;31m", "\033[1;37m")

MODES = {  # mode: (label, color)
    "jit": ("jit     java @tornado.args", YELLOW),
    "leyden": ("leyden  java -XX:AOTCache", BLUE),
    "native": ("native  target/matmul", GREEN),
}
PIPELINE_COLORS = (BLUE, CYAN, MAGENTA, GREEN, YELLOW)


def paint(color, s):
    return f"{color}{s}{RESET}" if COLOR else s


def visible(s):
    return len(re.sub(r"\033\[[0-9;]*m", "", s))


def pad(s, width):
    return s + " " * max(0, width - visible(s))


def box(lines, color=CYAN, width=76):
    width = max(width, max(visible(line) for line in lines) + 2)
    print(paint(color, "  ╔" + "═" * width + "╗"))
    for line in lines:
        print(paint(color, "  ║") + pad(line, width) + paint(color, "║"))
    print(paint(color, "  ╚" + "═" * width + "╝"))


def banner(title, subtitle):
    print()
    box([paint(BOLD, "   " + title), paint(DIM, "   " + subtitle)])


def act(number, title, subtitle):
    print()
    head = f"  ━━ {number} · {title} "
    print(paint(MAGENTA, head + "━" * max(3, 80 - len(head))))
    print("    " + subtitle)
    print()


def pipeline(*stages):
    """stages: NAME:KIND, drawn as boxes joined by arrows."""
    tops, mids, bots = [], [], []
    for n, stage in enumerate(stages):
        name, _, kind = stage.partition(":")
        color = PIPELINE_COLORS[n % len(PIPELINE_COLORS)]
        w = max(len(name), len(kind)) + 2
        tops.append(paint(color, "┌" + "─" * w + "┐"))
        mids.append(paint(color, "│") + paint(BOLD, name.center(w)) + paint(color, "│"))
        bots.append(paint(color, "└") + paint(DIM, kind.center(w, "─")) + paint(color, "┘"))
    for line in ("   ".join(tops), paint(WHITE, " ▶ ").join(mids), "   ".join(bots)):
        print("    " + line)
    print()


def read_rows(path):
    if not path or not os.path.exists(path):
        return []
    with open(path) as f:
        return [line.rstrip("\n").split("\t") for line in f if line.strip()]


def summary(starts, mode):
    """(median wall ms, median first execute() ms, correct, total) of one mode's starts, or None."""
    rows = [r for r in read_rows(starts) if r[0] == mode]
    if not rows:
        return None
    wall = statistics.median(int(r[1]) for r in rows)
    first = statistics.median(float(r[2]) for r in rows)
    return wall, first, sum(r[3] == "PASS" for r in rows), len(rows)


def starts(path, mode):
    s = summary(path, mode)
    if not s:
        return
    wall, first, ok, total = s
    mark = paint(GREEN, f"✔ {ok}/{total} correct") if ok == total else paint(RED, f"✘ {total - ok}/{total} wrong")
    print(f"    median {paint(BOLD, f'{wall:.0f} ms')} for the whole process"
          + paint(DIM, f"   ·   first execute() {first:.0f} ms of it") + f"   {mark}")
    print()


def compare(starts_path, checks_path, title):
    rows = [(m, *MODES[m], summary(starts_path, m)) for m in MODES]
    rows = [r for r in rows if r[3]]
    print()
    if rows:
        top = max(s[0] for *_, s in rows)
        best = min(s[0] for *_, s in rows)
        base = next((s[0] for m, *_, s in rows if m == "jit"), None)
        print("    " + paint(BOLD, title))
        print()
        for mode, label, color, (wall, first, _, _) in rows:
            n = min(WIDTH, max(1, round(wall / top * WIDTH)))
            k = min(n - 1, round(first / top * WIDTH)) if n > 1 else 0
            bar = paint(color, "█" * (n - k)) + paint(color, "░" * k) + " " * (WIDTH - n)
            gain = ""
            if base and mode != "jit":
                gain = paint(GREEN if wall < base else RED, f"{base / wall:4.1f}× faster" if wall < base else f"{wall / base:4.1f}× slower")
            star = paint(GREEN, " ★") if wall == best else ""
            print(f"    {pad(label, 28)} {bar} {wall:>6,.0f} ms  {gain}{star}")
        print()
        print(paint(DIM, "    █ start-up: the JVM or the executable, TornadoVM's runtime and driver"))
        print(paint(DIM, "    ░ the first execute(): TC compiles the kernel for the GPU, which then runs it"))
        print()
    checks = read_rows(checks_path)
    lines = [paint(BOLD, "  " + "start-up, ahead of time"), paint(DIM, "  " + "─" * 76)]
    for mode, label, _, (wall, first, ok, total) in rows:
        lines.append(f"  {label:<28}{wall:>6,.0f} ms  =  start-up {wall - first:>5,.0f} ms  +  execute() {first:>4,.0f} ms")
    box(lines)
    for verdict, text in checks:
        mark = {"PASS": paint(GREEN, "✔ "), "FAIL": paint(RED, "✘ ")}.get(verdict, paint(DIM, "– "))
        print("    " + mark + (paint(DIM, text) if verdict == "SKIP" else text))
    passed = rows and all(v != "FAIL" for v, _ in checks)
    print()
    print("PASSED -- every check holds" if passed else "FAILED -- a check did not hold (see above)")
    return 0 if passed else 1


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    handlers = {"banner": banner, "act": act, "pipeline": pipeline, "starts": starts, "compare": compare}
    return handlers[argv[1]](*argv[2:]) or 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
