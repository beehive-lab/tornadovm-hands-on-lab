#!/usr/bin/env python3
"""Terminal rendering for L14's run.sh: banners, act headers, pipelines, bar charts and a scoreboard, drawn from the
real output of each program (the logs run.sh captures). Standard library only. NO_COLOR=1 disables colors.
The same look as devoxx/fancy.py in the CUDA demos repository (L04, L05), cut down to what this lab draws.

    fancy.py banner       TITLE SUBTITLE
    fancy.py act          N TITLE SUBTITLE
    fancy.py hybrid-tasks LOG      MlxSgemvHybrid: per-task kernel times of the Java + MLX task graph
    fancy.py hybrid-gemm  LOG      MlxGemmBenefit: the same SGEMM as a Java kernel and as Mlx::matmul
    fancy.py scoreboard   TITLE    every row the renders above recorded (in $FANCY_STATE), with checks

Each render appends its headline row and its check to $FANCY_STATE, so run.sh can end with a scoreboard.
"""
import os
import re
import statistics
import sys

COLOR = os.environ.get("NO_COLOR") is None
STATE = os.environ.get("FANCY_STATE")
WIDTH = 46

RESET, BOLD, DIM = "\033[0m", "\033[1m", "\033[2m"
GREEN, YELLOW, CYAN, MAGENTA, BLUE, RED, WHITE = (
    "\033[1;32m", "\033[1;33m", "\033[1;36m", "\033[1;35m", "\033[1;34m", "\033[1;31m", "\033[1;37m")


def paint(color, s):
    return f"{color}{s}{RESET}" if COLOR else s


def visible(s):
    return len(re.sub(r"\033\[[0-9;]*m", "", s))


def pad(s, width):
    return s + " " * max(0, width - visible(s))


def read(path):
    with open(path, errors="replace") as f:
        return re.sub(r"\033\[[0-9;]*m", "", f.read())


def record(row, value, ok=True, check=None):
    """Remember a scoreboard row and its check for `scoreboard`."""
    if STATE:
        with open(STATE, "a") as f:
            f.write(f"{row}\t{value}\t{'PASS' if ok else 'FAIL'}\t{check or ''}\n")


# --- building blocks ------------------------------------------------------------------------------------------

def box(lines, color=CYAN, width=72):
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
    print(paint(MAGENTA, head + "━" * max(3, 76 - len(head))))
    print("    " + subtitle)
    print()


def bars(title, rows, unit, fmt="{:,.1f}", lower_is_better=True):
    """rows: (label, value, color). One scale: the largest value fills the width. The best value gets a star."""
    top = max(v for _, v, _ in rows)
    best = (min if lower_is_better else max)(v for _, v, _ in rows)
    print("    " + paint(BOLD, title))
    for label, value, color in rows:
        n = max(1, round(value / top * WIDTH))
        star = paint(GREEN, " ★") if value == best else ""
        print(f"    {pad(label, 34)} {paint(color, '█' * n)}{' ' * (WIDTH - n)} {fmt.format(value):>9} {unit}{star}")
    print()


def pipeline(stages):
    """stages: (name, kind, color) drawn as boxes joined by arrows."""
    tops, mids, bots = [], [], []
    for name, kind, color in stages:
        w = max(len(name), len(kind)) + 2
        tops.append(paint(color, "┌" + "─" * w + "┐"))
        mids.append(paint(color, "│") + paint(BOLD, name.center(w)) + paint(color, "│"))
        bots.append(paint(color, "└") + paint(DIM, kind.center(w, "─")) + paint(color, "┘"))
    for line in ("   ".join(tops), paint(WHITE, " ▶ ").join(mids), "   ".join(bots)):
        print("    " + line)
    print()


def big(text, color=GREEN):
    print(f"    {paint(color, '▶ ' + text)}")
    print()


# --- demo renders ---------------------------------------------------------------------------------------------

TASKS = {"MlxSgemvHybrid.scale": ("scale", "Java → MSL", BLUE), "mlx_matmul": ("Mlx::matmul", "Apple MLX", GREEN),
         "MlxSgemvHybrid.bias": ("bias", "Java → MSL", BLUE)}
ORDER = ("MlxSgemvHybrid.scale", "mlx_matmul", "MlxSgemvHybrid.bias")


def hybrid_tasks(log):
    text = read(log)
    pipeline([TASKS[k] for k in ORDER])
    # per iteration: the task kernel times printed before each "iteration i:" line
    iterations, current, method = [], {}, None
    for line in text.splitlines():
        m = re.search(r'"METHOD":\s*"([^"]+)"', line)
        if m:
            method = m.group(1)
        m = re.search(r'"TASK_KERNEL_TIME":\s*"?([0-9.]+)', line)
        if m and method:
            current[method] = float(m.group(1)) / 1000
        m = re.match(r"iteration (\d+): (\w+)", line)
        if m:
            iterations.append((int(m.group(1)), m.group(2), dict(current)))
            current = {}
    print("    " + paint(BOLD, "kernel time per task, every iteration on the GPU") + paint(DIM, "   (µs)"))
    for i, status, times in iterations:
        cells = []
        for key in ORDER:
            t = times.get(key)
            cells.append(f"{TASKS[key][0]:>11} {t:8.1f}" if t is not None else f"{TASKS[key][0]:>11} {'-':>8}")
        mark = paint(GREEN, "✔ correct") if status == "correct" else paint(RED, "✘ " + status)
        print(f"    iteration {i}  " + "  ".join(cells) + "   " + mark)
    if iterations:
        print(paint(DIM, "    iteration 0 includes MLX's one-time setup"))
    print()
    ok = "All iterations correct" in text and len(iterations) > 0
    steady = [sum(t.values()) for i, _, t in iterations if i > 0]
    if steady:
        big(f"Java kernels and MLX share device buffers: {statistics.median(steady):.0f} µs of kernel time per pass, no host round trip")
    record("Hybrid: Java → MLX → Java", f"{len(iterations)} iterations, all correct" if ok else "INCORRECT", ok,
           "hybrid: every iteration correct")


def hybrid_gemm(log):
    text = read(log)
    m = re.search(r"java=(\d+) us, mlx=(\d+) us, speedup=([0-9.]+)x, java=(\d+) GFLOP/s, mlx=(\d+) GFLOP/s", text)
    size = re.search(r"SGEMM (\d+ x \d+ x \d+), (\d+) executions", text)
    first = dict(re.findall(r"^(java kernel|Mlx::matmul): first execution (\d+) us", text, re.M))
    if not (m and size):
        print(paint(RED, "    no steady-state summary in the log"))
        record("Java kernel vs Mlx::matmul", "missing", False, "gemm: summary present")
        return
    java, mlx, speedup, gjava, gmlx = int(m.group(1)), int(m.group(2)), float(m.group(3)), int(m.group(4)), int(m.group(5))
    bars(f"SGEMM {size.group(1)}, median wall clock per execute() of {int(size.group(2)) - 1}",
         [("@Parallel Java kernel", java, YELLOW), ("Mlx::matmul", mlx, GREEN)], "µs", fmt="{:,.0f}")
    print(f"    throughput: Java kernel {gjava:,} GFLOP/s, Mlx::matmul {paint(BOLD, f'{gmlx:,}')} GFLOP/s"
          + paint(DIM, "   (times include copying C back)"))
    if len(first) == 2:
        print(paint(DIM, f"    first runs: Java kernel {int(first['java kernel']) / 1000:.0f} ms (JIT to MSL), "
                         f"MLX {int(first['Mlx::matmul']) / 1000:.0f} ms (setup)"))
    print()
    big(f"{speedup:.1f}x faster with one line: .libraryTask(\"matmul\", Mlx::matmul, a, b, c, n, n, n)")
    ok = text.count("All executions correct") == 2
    record("Java kernel vs Mlx::matmul", f"{java:,} µs → {mlx:,} µs  {speedup:.1f}x", ok, "gemm: every execution correct, both ways")


def scoreboard(title):
    rows = []
    if STATE and os.path.exists(STATE):
        with open(STATE) as f:
            rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    print()
    box([paint(BOLD, f"  {title}"), paint(DIM, "  " + "─" * 68)] + [f"  {r[0]:<34}{r[1][:36]}" for r in rows])
    for verdict, check in [(r[2], r[3]) for r in rows if r[3]]:
        print("    " + (paint(GREEN, "✔ ") if verdict == "PASS" else paint(RED, "✘ ")) + check)
    ok = rows and all(r[2] == "PASS" for r in rows)
    print()
    print("PASSED -- every check holds" if ok else "FAILED -- a check did not hold (see above)")


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    handlers = {"banner": banner, "act": act, "hybrid-tasks": hybrid_tasks, "hybrid-gemm": hybrid_gemm,
                "scoreboard": scoreboard}
    handlers[argv[1]](*argv[2:])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
