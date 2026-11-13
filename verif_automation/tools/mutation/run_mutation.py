#!/usr/bin/env python3
#
# Filename:         run_mutation.py
#
# File Description: Mutation testing of the RTL against its own verification.
#                   For each mutant (mutants.py): copy the RTL tree to a
#                   scratch folder, make the one edit there, and run the
#                   mutated module's own testbench - with its bound checker -
#                   through the existing sim/ targets, pointed at the copy by
#                   SV_DIR. The real rtl-systemverilog/ is never written.
#
#                   Each mutant ends as one of:
#                     killed     the testbench or a checker failed
#                     lint       Verilator -Wall refused it (the build runs
#                                with -Wall, as make lint does): caught
#                                before simulation
#                     timeout    the run did not finish in time (a hang the
#                                watchdog did not end)
#                     survived   everything passed - a gap in the
#                                verification, or a mutant that changes
#                                nothing (an equivalent mutant); telling the
#                                two apart is a judgement this tool does not
#                                make
#                     stillborn  not a legal design (a hard compile error);
#                                left out of the score
#                   Score = (killed + lint + timeout) / (all - stillborn).
#
#                   Every target is first run on the unmutated RTL; a target
#                   that does not pass there stops the run.
#
#                   Usage: run_mutation.py [--modules a,b] [--operators X,Y]
#                                          [--sample N] [--seed S] [--jobs J]
#                                          [--ids ID,ID] [--list] [--evidence]
#                     --list      list the mutants and stop (no simulation)
#                     --evidence  also save the report and results under
#                                 evidence/mutation/<date>_mutation.{txt,json}
#                   Output: verif_automation/build/mutation/<run>/report.txt
#                   and results.json.
#
# Global variables: REPO, TARGETS, DEFAULT_TARGET - see below

import argparse
import concurrent.futures
import datetime
import json
import os
import pathlib
import random
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import mutants as M  # noqa: E402

# REPO: the repository root
REPO = pathlib.Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True,
                                   cwd=pathlib.Path(__file__).parent).stdout.strip()
                    or pathlib.Path(__file__).resolve().parents[3])
# TARGETS: the sim/ make target that tests each module, and the testbench
#          top whose build folder holds the result, where it is not the
#          module's own unit testbench (tb_<module>, <module>_tb)
TARGETS = {
    "spi_slave": ("tb_host_if", "host_if_tb"),
    "reg_file": ("tb_host_if", "host_if_tb"),
    "pmic_top": ("tb_top", "pmic_top_tb"),
}
# DEFAULT_TARGET: the unit testbench of a module
DEFAULT_TARGET = ("tb_{m}", "{m}_tb")


def target_of(module):
    """Purpose: (make target, testbench top) that tests a module."""
    t, top = TARGETS.get(module, DEFAULT_TARGET)
    return t.format(m=module), top.format(m=module)


def all_mutants():
    """Purpose: every mutant of every tracked RTL file, in file order."""
    files = subprocess.run(["git", "ls-files", "--", "rtl-systemverilog"], cwd=REPO, capture_output=True,
                           text=True).stdout.split()
    out = []
    for rel in sorted(f for f in files if f.endswith(".sv")):
        out += M.find(str(REPO / rel), rel)
    return out


def run_target(target, top, sv_dir, build, timeout):

    """
    Purpose: Run one sim/ target against the RTL tree in sv_dir, building in
             build. Returns (status, seconds, detail).
    """
    build.mkdir(parents=True, exist_ok=True)
    cmd = ["make", "-s", "-C", str(REPO / "sim"), target, f"SV_DIR={sv_dir}", f"TBBUILD={build}",
           "QUIET=1", "NOFAIL=1", "VJOBS=1", "COLOR=0"]
    start = time.time()
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                       env={**os.environ, "MAKEFLAGS": ""})
    except subprocess.TimeoutExpired:
        return "timeout", time.time() - start, f"no result after {timeout:.0f} s"
    secs = time.time() - start
    d = build / "sv" / top
    result = d / "result.tsv"
    verdict = result.read_text().split("\t")[2] if result.exists() else "FAIL"
    simulated = (d / "results.xml").exists() if target.endswith(("cocotb", "host_if")) else (d / "run.log").exists()
    if not simulated:
        log = d / "build.log" if (d / "build.log").exists() else d / "run.log"
        text = log.read_text(errors="replace") if log.exists() else ""
        errors = [l for l in text.splitlines() if l.startswith("%Error") and "Exiting due to" not in l]
        warnings = sorted({m.group(1) for m in re.finditer(r"%Warning-(\w+)", text)})
        if warnings and not errors:
            return "lint", secs, "Verilator: " + ", ".join(warnings)
        return "stillborn", secs, (errors[0][:120] if errors else "build failed")
    if verdict == "FAIL":
        return "killed", secs, ""
    if verdict == "INCONCLUSIVE":
        return "survived", secs, "a cover read zero"
    return "survived", secs, ""


def run_one(m, work, timeout, keep):

    """
    Purpose: Make one mutant in a scratch copy of the RTL and test it.
    """
    root = work / m.id
    shutil.rmtree(root, ignore_errors=True)
    tree = root / "rtl-systemverilog"
    shutil.copytree(REPO / "rtl-systemverilog", tree)
    path = REPO / m.file
    raw = path.read_bytes().decode("utf-8", "replace")
    text = m.apply(raw.replace("\r", ""))
    (tree / pathlib.Path(m.file).relative_to("rtl-systemverilog")).write_bytes(
        (text.replace("\n", "\r\n") if "\r\n" in raw else text).encode())
    target, top = target_of(m.unit)
    status, secs, detail = run_target(target, top, tree, root / "build", timeout)
    if not keep:
        shutil.rmtree(root, ignore_errors=True)
    return status, secs, detail


def line_pair(m):
    """Purpose: the mutated line before and after the edit."""
    text = M.source_text(str(REPO / m.file))
    return text.split("\n")[m.line - 1].strip(), m.apply(text).split("\n")[m.line - 1].strip()


def report(results, header):

    """
    Purpose: The text report: header, per-module and per-operator tables,
             and every survivor with its line before and after.
    """
    out = header + [""]
    cols = ["killed", "lint", "timeout", "survived", "stillborn"]

    def table(key, title):
        rows = {}
        for r in results:
            rows.setdefault(r[key], {c: 0 for c in cols})[r["status"]] += 1
        out.append(f"{title:<16}{'mutants':>8}" + "".join(f"{c:>11}" for c in cols) + f"{'score':>8}")
        tot = {c: 0 for c in cols}
        for name in sorted(rows):
            row = rows[name]
            for c in cols:
                tot[c] += row[c]
            out.append(_row(name, row, cols))
        out.append(_row("TOTAL", tot, cols))
        out.append("")
    table("unit", "module")
    table("operator", "operator")
    surv = [r for r in results if r["status"] == "survived"]
    out.append(f"SURVIVORS ({len(surv)})")
    out.append("")
    for r in surv:
        out.append(f"  {r['id']}  {r['file']}:{r['line']}  {r['operator']}  {r['description']}"
                   + (f"  [{r['detail']}]" if r["detail"] else ""))
        out.append(f"      before: {r['before']}")
        out.append(f"      after:  {r['after']}")
    other = [r for r in results if r["status"] in ("stillborn", "timeout")]
    if other:
        out += ["", f"STILLBORN AND TIMEOUT ({len(other)})", ""]
        out += [f"  {r['id']}  {r['status']}  {r['detail']}" for r in other]
    return "\n".join(out) + "\n"


def _row(name, row, cols):
    """Purpose: one table row with the score."""
    n = sum(row.values())
    live = n - row["stillborn"]
    score = f"{100 * (row['killed'] + row['lint'] + row['timeout']) / live:.1f}%" if live else "-"
    return f"{name:<16}{n:>8}" + "".join(f"{row[c]:>11}" for c in cols) + f"{score:>8}"


def main():

    """
    Purpose: Select the mutants, check every target passes unmutated, run the
             mutants in parallel, and write the report and results.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--modules")
    ap.add_argument("--operators")
    ap.add_argument("--ids")
    ap.add_argument("--sample", type=int)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--timeout-factor", type=float, default=10.0)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--keep", action="store_true", help="keep each mutant's scratch folder")
    ap.add_argument("--evidence", action="store_true")
    args = ap.parse_args()

    ms = all_mutants()
    total_found = len(ms)
    if args.modules:
        want = set(args.modules.split(","))
        ms = [m for m in ms if m.unit in want]
    if args.operators:
        want = set(args.operators.split(","))
        ms = [m for m in ms if m.operator in want]
    if args.ids:
        want = set(args.ids.split(","))
        ms = [m for m in ms if m.id in want]
    if args.sample and args.sample < len(ms):
        ms = sorted(random.Random(args.seed).sample(ms, args.sample), key=lambda m: (m.file, m.start))
    if args.list:
        for m in ms:
            print(f"{m.id:36s} {m.file}:{m.line:<5d} {m.operator}  {m.description}")
        print(f"{len(ms)} mutants (of {total_found})")
        return

    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                            text=True).stdout.strip() or "unknown"
    dirty = subprocess.run(["git", "status", "--porcelain", "--", "rtl-systemverilog", "sva", "tb"], cwd=REPO,
                           capture_output=True, text=True).stdout.strip()
    run_name = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    out = REPO / "verif_automation" / "build" / "mutation" / run_name
    work = out / "work"
    work.mkdir(parents=True, exist_ok=True)

    # baseline: every target used must pass on the unmutated RTL
    baseline = {}
    for target, top in sorted({target_of(m.unit) for m in ms}):
        print(f"baseline  {target} ...", flush=True)
        status, secs, detail = run_target(target, top, REPO / "rtl-systemverilog", out / "baseline" / target, 3600)
        if status != "survived" or detail:
            sys.exit(f"baseline: {target} does not pass on the unmutated RTL ({status} {detail}) - fix that first")
        baseline[target] = secs
    print(f"running {len(ms)} mutants on {args.jobs} jobs", flush=True)

    results, done = [], 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_one, m, work,
                               max(120.0, args.timeout_factor * baseline[target_of(m.unit)[0]]), args.keep): m
                   for m in ms}
        for fut in concurrent.futures.as_completed(futures):
            m = futures[fut]
            status, secs, detail = fut.result()
            before, after = line_pair(m)
            results.append({"id": m.id, "file": m.file, "unit": m.unit, "line": m.line, "operator": m.operator,
                            "description": m.description, "status": status, "detail": detail,
                            "seconds": round(secs, 1), "before": before, "after": after})
            done += 1
            print(f"[{done}/{len(ms)}] {status:9s} {m.id}  {m.description}", flush=True)
    results.sort(key=lambda r: (r["file"], r["line"], r["id"]))
    if not args.keep:
        shutil.rmtree(work, ignore_errors=True)

    scope = (f"{len(ms)} mutants" + (f" (sample of {total_found}, seed {args.seed})" if args.sample else
                                     f" of {total_found}"))
    header = [f"mutation report - {datetime.date.today().isoformat()} - commit {commit}"
              + (" (uncommitted changes in rtl / sva / tb)" if dirty else ""),
              f"scope: {scope}; modules: {args.modules or 'all'}; operators: {args.operators or 'all'}",
              "tests: each module's own testbench with its bound checker (reg_file and spi_slave: the host_if "
              "cocotb suite; pmic_top: the integration testbench)",
              "baseline: " + ", ".join(f"{t} passes ({s:.0f} s)" for t, s in sorted(baseline.items())),
              "score = (killed + lint + timeout) / (mutants - stillborn); a survivor is a gap or an "
              "equivalent mutant - not judged here"]
    text = report(results, header)
    (out / "report.txt").write_text(text)
    (out / "results.json").write_text(json.dumps({"header": header, "results": results}, indent=1) + "\n")
    print(text)
    print(f"report: {out / 'report.txt'}")
    if args.evidence:
        ev = REPO / "verif_automation" / "evidence" / "mutation"
        ev.mkdir(parents=True, exist_ok=True)
        stem = f"{datetime.date.today().isoformat()}_mutation"
        n = 1
        while (ev / f"{stem}{'' if n == 1 else f'_{n}'}.txt").exists():
            n += 1
        stem = f"{stem}{'' if n == 1 else f'_{n}'}"
        shutil.copy(out / "report.txt", ev / f"{stem}.txt")
        shutil.copy(out / "results.json", ev / f"{stem}.json")
        print(f"evidence: {ev / stem}.txt / .json")


if __name__ == "__main__":
    main()
