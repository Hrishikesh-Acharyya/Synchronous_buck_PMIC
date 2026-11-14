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
#                     lint       Verilator -Wall refused it - make lint on the
#                                whole design, run first on every mutant, or
#                                the testbench build, which also uses -Wall:
#                                caught before simulation
#                     covers     every check passed, but an SVA cover the
#                                unmutated run hits was not hit: the
#                                regression would read INCONCLUSIVE, not
#                                PASS - caught, but only by a lost cover
#                     timeout    the run did not finish in time (a hang the
#                                watchdog did not end)
#                     survived   everything passed - a gap in the
#                                verification, or a mutant that changes
#                                nothing (an equivalent mutant); telling the
#                                two apart is a judgement this tool does not
#                                make
#                     stillborn  not a legal design (a hard compile error);
#                                left out of the score
#                     ai_equiv   judged equivalent by the triage (--triage)
#                                and not simulated; left out of the score
#                   Score = (killed + lint + covers + timeout) / (all -
#                   stillborn - ai_equiv).
#
#                   With --triage FILE (the output of the AI triage task),
#                   a mutant judged "equivalent" with high confidence is not
#                   a test target. --audit says how many of those are
#                   simulated anyway: an equivalent mutant can never be
#                   killed, so every one that is killed is a triage error,
#                   and is reported as one. The default audits all of them.
#
#                   Every mutant is first screened with make lint (a fraction
#                   of a second); only the ones it accepts are simulated.
#                   Every target is first run on the unmutated RTL; a target
#                   that fails there stops the run. A surviving mutant that
#                   hits fewer SVA covers than that run did is marked so.
#
#                   The random tests inside a suite (the host_if suite's
#                   random walk) run with one fixed seed, the same for the
#                   baseline and every mutant, so a mutant's outcome is the
#                   same every time it is run.
#
#                   Usage: run_mutation.py [--modules a,b] [--operators X,Y]
#                                          [--sample N] [--seed S] [--jobs J]
#                                          [--ids ID,ID] [--sim-args "V=1 ..."]
#                                          [--triage FILE] [--audit all|N|0]
#                                          [--list] [--check] [--evidence]
#                     --seed      the seed for --sample and for the suites'
#                                 random tests (default 1)
#                     --sim-args  extra make variables for the sim/ target,
#                                 e.g. "HOSTIF_EVENTS=4000" to re-run
#                                 survivors against a longer random walk
#                     --list      list the mutants and stop (no simulation)
#                     --check     screen every mutant with make lint and stop:
#                                 how many are legal, how many lint catches -
#                                 a health check of the mutant generator
#                     --evidence  also save the report and results under
#                                 evidence/mutation/<date>_mutation.{txt,json}
#                                 and add the run to evidence/mutation/README.md
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
    "pmic_types_pkg": ("tb_top", "pmic_top_tb"),
}
# DEFAULT_TARGET: the unit testbench of a module
DEFAULT_TARGET = ("tb_{m}", "{m}_tb")
# AI_STORE: where the mutants written by the AI step are kept
AI_STORE = REPO / "verif_automation" / "ai" / "mutants"


def target_of(module):
    """Purpose: (make target, testbench top) that tests a module."""
    t, top = TARGETS.get(module, DEFAULT_TARGET)
    return t.format(m=module), top.format(m=module)


def mechanical_mutants():
    """Purpose: every mutant the operators make, of every tracked RTL file, in file order."""
    files = subprocess.run(["git", "ls-files", "--", "rtl-systemverilog"], cwd=REPO, capture_output=True,
                           text=True).stdout.split()
    info = M.design_info(REPO / "rtl-systemverilog")
    out = []
    for rel in sorted(f for f in files if f.endswith(".sv")):
        out += M.find(str(REPO / rel), rel, info)
    return out


def all_mutants():

    """
    Purpose: Every mutant: the mechanical ones, and the ones the AI step
             wrote (AI_STORE). An AI-written mutant whose lines have changed
             since it was written cannot be placed; those are counted in
             RUN["stale"] and reported.
    """
    written, RUN["stale"] = M.written(AI_STORE, REPO)
    return sorted(mechanical_mutants() + written, key=lambda m: (m.file, m.start, m.operator, m.id))


def screen(sv_dir):

    """
    Purpose: Run make lint on the RTL tree in sv_dir. Returns (status,
             detail): clean, lint (warnings, named), or stillborn (a hard
             error - not a legal design).
    """
    p = subprocess.run(["make", "-s", "-C", str(REPO / "sim"), "lint", f"SV_DIR={sv_dir}", "COLOR=0"],
                       capture_output=True, text=True, env={**os.environ, "MAKEFLAGS": ""})
    text = p.stdout + p.stderr
    errors = [l for l in text.splitlines() if l.startswith("%Error") and "Exiting due to" not in l]
    warnings = sorted({m.group(1) for m in re.finditer(r"%Warning-(\w+)", text)})
    if errors:
        return "stillborn", re.sub(r"/\S*/rtl-systemverilog/", "", errors[0])[:120]
    if warnings:
        return "lint", "make lint: " + ", ".join(warnings)
    if p.returncode != 0:
        return "stillborn", "make lint failed: " + text.strip()[-100:]
    return "clean", ""


# RUN: per-run settings shared by every worker - the suites' random seed and
#      any extra make variables for the sim/ targets
RUN = {"seed": 1, "sim_args": [], "covers": {}, "stale": []}


def run_target(target, top, sv_dir, build, timeout):

    """
    Purpose: Run one sim/ target against the RTL tree in sv_dir, building in
             build. The suite's random seed is fixed (cocotb reads it from
             the environment), so every run of a target draws the same
             random tests. Returns (status, seconds, detail, covers hit -
             None when nothing was simulated).
    """
    build.mkdir(parents=True, exist_ok=True)
    cmd = ["make", "-s", "-C", str(REPO / "sim"), target, f"SV_DIR={sv_dir}", f"TBBUILD={build}",
           "QUIET=1", "NOFAIL=1", "VJOBS=1", "COLOR=0", *RUN["sim_args"]]
    seed = str(RUN["seed"])
    start = time.time()
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                       env={**os.environ, "MAKEFLAGS": "", "RANDOM_SEED": seed, "COCOTB_RANDOM_SEED": seed})
    except subprocess.TimeoutExpired:
        return "timeout", time.time() - start, f"no result after {timeout:.0f} s", None
    secs = time.time() - start
    d = build / "sv" / top
    result = d / "result.tsv"
    fields = result.read_text().split("\t") if result.exists() else []
    verdict = fields[2] if len(fields) > 2 else "FAIL"
    covers = int(fields[4]) if len(fields) > 4 and fields[4].isdigit() else None
    simulated = (d / "results.xml").exists() if target.endswith(("cocotb", "host_if")) else (d / "run.log").exists()
    if not simulated:
        log = d / "build.log" if (d / "build.log").exists() else d / "run.log"
        text = log.read_text(errors="replace") if log.exists() else ""
        errors = [l for l in text.splitlines() if l.startswith("%Error") and "Exiting due to" not in l]
        warnings = sorted({m.group(1) for m in re.finditer(r"%Warning-(\w+)", text)})
        if warnings and not errors:
            return "lint", secs, "Verilator: " + ", ".join(warnings), None
        return "stillborn", secs, (errors[0][:120] if errors else "build failed"), None
    if verdict == "FAIL":
        return "killed", secs, "", covers
    return "survived", secs, "", covers


def run_one(m, work, timeout, keep, simulate=True):

    """
    Purpose: Make one mutant in a scratch copy of the RTL, screen it with
             make lint, and - if lint accepts it and simulate is set - test
             it.
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
    start = time.time()
    status, detail = screen(tree)
    secs = time.time() - start
    if status == "clean" and simulate:
        target, top = target_of(m.unit)
        status, secs, detail, covers = run_target(target, top, tree, root / "build", timeout)
        base = RUN["covers"].get(target)
        if status == "survived" and covers is not None and base is not None and covers < base:
            status, detail = "covers", f"hit {covers} SVA covers, the unmutated run {base}"
    if not keep:
        shutil.rmtree(root, ignore_errors=True)
    return status, secs, detail


def repeats(ms):

    """
    Purpose: For --check: the mutants that are not a mutant of their own -
             each (id, what) where what is "changes no code" or "the same
             code as <id>". Compared with comments and spacing taken out.
    """
    out, by_file = [], {}
    for m in ms:
        by_file.setdefault(m.file, []).append(m)
    for file, group in by_file.items():
        text = M.source_text(str(REPO / file))
        seen = {M.code_key(text): None}
        for m in group:
            key = M.code_key(m.apply(text))
            if key in seen:
                out.append((m.id, "changes no code" if seen[key] is None else f"the same code as {seen[key]}"))
            else:
                seen[key] = m.id
    return out


def line_pair(m):

    """
    Purpose: The mutated line before and after the edit. For an edit of
             several lines (an AI-written mutant), every line it replaces
             and every line it puts there, joined with " / ".
    """
    text = M.source_text(str(REPO / m.file))
    if m.operator != M.AI_OPERATOR:
        return text.split("\n")[m.line - 1].strip(), m.apply(text).split("\n")[m.line - 1].strip()
    old, new = text[m.start:m.end].split("\n"), m.new_text.split("\n")
    while len(old) > 1 and len(new) > 1 and old[0].strip() == new[0].strip():
        old, new = old[1:], new[1:]
    while len(old) > 1 and len(new) > 1 and old[-1].strip() == new[-1].strip():
        old, new = old[:-1], new[:-1]
    return " / ".join(x.strip() for x in old), " / ".join(x.strip() for x in new)


def report(results, header):

    """
    Purpose: The text report: header, per-module and per-operator tables,
             and every survivor with its line before and after.
    """
    out = header + [""]
    cols = ["killed", "lint", "covers", "timeout", "survived", "stillborn"]
    if any(r["status"] == "ai_equiv" for r in results):
        cols.append("ai_equiv")
    if any(r["status"] == "clean" for r in results):
        cols = ["clean", "lint", "stillborn"]          # a --check run: nothing simulated

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
    if "survived" in cols:
        out.append(f"SURVIVORS ({len(surv)})")
        out.append("")
    for r in surv:
        out.append(f"  {r['id']}  {r['file']}:{r['line']}  {r['operator']}  {r['description']}"
                   + (f"  [{r['detail']}]" if r["detail"] else ""))
        out.append(f"      before: {r['before']}")
        out.append(f"      after:  {r['after']}")
        if r.get("triage"):
            t = r["triage"]
            out.append(f"      triage: {t['verdict']} ({t['confidence']}) - {t['reason']}")
    judged = [r for r in results if r.get("triage")]
    if judged:
        eq = [r for r in judged if r["triage"]["verdict"] == "equivalent" and r["triage"]["confidence"] == "high"]
        audited = [r for r in eq if r["status"] != "ai_equiv"]
        wrong = [r for r in audited if r["status"] in ("killed", "covers", "timeout")]
        out += ["", "AI TRIAGE", "",
                f"  judged: {len(judged)}   plausible: {len(judged) - len(eq)}   equivalent (high confidence): {len(eq)}",
                f"  audited by simulation: {len(audited)} of {len(eq)}   contradicted (judged equivalent, but "
                f"killed): {len(wrong)}", ""]
        for r in wrong:
            out.append(f"  TRIAGE ERROR  {r['id']}  {r['file']}:{r['line']}  {r['operator']}  {r['description']}")
            out.append(f"      the triage said: {r['triage']['reason']}")
    weak = [r for r in results if r["status"] == "covers"]
    if weak:
        out += ["", f"CAUGHT ONLY BY A LOST COVER ({len(weak)}) - no check failed", ""]
        for r in weak:
            out.append(f"  {r['id']}  {r['file']}:{r['line']}  {r['operator']}  {r['description']}  [{r['detail']}]")
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
    live = n - row["stillborn"] - row.get("ai_equiv", 0)
    if "clean" in cols:
        score = "-"
    else:
        score = f"{100 * (row['killed'] + row['lint'] + row['covers'] + row['timeout']) / live:.1f}%" if live else "-"
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
    ap.add_argument("--sim-args", default="")
    ap.add_argument("--triage")
    ap.add_argument("--audit", default="all")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--timeout-factor", type=float, default=10.0)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--keep", action="store_true", help="keep each mutant's scratch folder")
    ap.add_argument("--evidence", action="store_true")
    args = ap.parse_args()

    RUN["seed"] = args.seed
    RUN["sim_args"] = args.sim_args.split()
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
    # triage: which mutants were judged equivalent, and which of those to audit
    triage, skip = {}, set()
    if args.triage:
        triage = json.loads(pathlib.Path(args.triage).read_text())["verdicts"]
        eq = [m.id for m in ms if triage.get(m.id, {}).get("verdict") == "equivalent"
              and triage[m.id].get("confidence") == "high"]
        if args.audit != "all":
            keep = set(random.Random(args.seed).sample(eq, min(int(args.audit), len(eq))))
            skip = set(eq) - keep
    if args.list:
        for m in ms:
            print(f"{m.id:36s} {m.file}:{m.line:<5d} {m.operator}  {m.description}")
        print(f"{len(ms)} mutants (of {total_found})")
        if RUN["stale"]:
            print(f"{len(RUN['stale'])} AI-written mutants no longer match the RTL and are left out: "
                  + ", ".join(RUN["stale"]))
        return

    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                            text=True).stdout.strip() or "unknown"
    dirty = subprocess.run(["git", "status", "--porcelain", "--", "rtl-systemverilog", "sva", "tb"], cwd=REPO,
                           capture_output=True, text=True).stdout.strip()
    run_name = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    out = REPO / "verif_automation" / "build" / "mutation" / run_name
    work = out / "work"
    work.mkdir(parents=True, exist_ok=True)

    # baseline: make lint, and every target used, must pass on the unmutated RTL
    status, detail = screen(REPO / "rtl-systemverilog")
    if status != "clean":
        sys.exit(f"baseline: make lint does not pass on the unmutated RTL ({detail}) - fix that first")
    baseline = {}
    for target, top in sorted({target_of(m.unit) for m in ms} if not args.check else []):
        print(f"baseline  {target} ...", flush=True)
        status, secs, detail, covers = run_target(target, top, REPO / "rtl-systemverilog",
                                                  out / "baseline" / target, 3600)
        if status != "survived":
            sys.exit(f"baseline: {target} fails on the unmutated RTL ({status} {detail}) - fix that first")
        baseline[target] = secs
        RUN["covers"][target] = covers
    print(f"running {len(ms)} mutants on {args.jobs} jobs", flush=True)

    results, done = [], 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_one, m, work,
                               max(120.0, args.timeout_factor * baseline.get(target_of(m.unit)[0], 0)),
                               args.keep, not args.check and m.id not in skip): m
                   for m in ms}
        for fut in concurrent.futures.as_completed(futures):
            m = futures[fut]
            status, secs, detail = fut.result()
            if status == "clean" and m.id in skip:
                status, detail = "ai_equiv", "judged equivalent by the triage; not simulated"
            before, after = line_pair(m)
            results.append({"id": m.id, "file": m.file, "unit": m.unit, "line": m.line, "operator": m.operator,
                            "description": m.description, "status": status, "detail": detail,
                            "seconds": round(secs, 1), "before": before, "after": after})
            if m.id in triage:
                results[-1]["triage"] = triage[m.id]
            done += 1
            if not args.check or status != "clean":
                print(f"[{done}/{len(ms)}] {status:9s} {m.id}  {m.description}"
                      + (f"  [{detail}]" if detail and status in ("lint", "stillborn") else ""), flush=True)
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
              "baseline: make lint passes" + "".join(f", {t} passes ({s:.0f} s)" for t, s in sorted(baseline.items())),
              f"random tests: seed {args.seed}" + (f"; extra sim settings: {args.sim_args}" if args.sim_args else ""),
              *([f"triage: {args.triage}; audit of the mutants it judged equivalent: {args.audit}"]
                if args.triage else []),
              "score = (killed + lint + covers + timeout) / (mutants - stillborn - ai_equiv); a survivor is a "
              "gap or an equivalent mutant"]
    if args.check:
        same = repeats(ms)
        header[2:] = ["check only: every mutant screened with make lint, none simulated",
                      "clean = legal and accepted by lint (would be simulated); lint = caught by make lint; "
                      "stillborn = not legal code (a fault in the mutant generator if it is not 0)",
                      f"repeats: {len(same)} mutants change no code or are the same code as another (should be 0)"
                      + "".join(f"\n  {mid}: {what}" for mid, what in same)]
    if RUN["stale"]:
        header.append(f"left out: {len(RUN['stale'])} AI-written mutants whose lines have changed since they "
                      f"were written ({', '.join(RUN['stale'])})")
    text = report(results, header)
    (out / "report.txt").write_text(text)
    (out / "results.json").write_text(json.dumps({"header": header, "results": results}, indent=1) + "\n")
    print(text)
    print(f"report: {out / 'report.txt'}")
    if args.evidence and not args.check:
        ev = REPO / "verif_automation" / "evidence" / "mutation"
        ev.mkdir(parents=True, exist_ok=True)
        stem = f"{datetime.date.today().isoformat()}_mutation"
        n = 1
        while (ev / f"{stem}{'' if n == 1 else f'_{n}'}.txt").exists():
            n += 1
        stem = f"{stem}{'' if n == 1 else f'_{n}'}"
        shutil.copy(out / "report.txt", ev / f"{stem}.txt")
        shutil.copy(out / "results.json", ev / f"{stem}.json")
        index = ev / "README.md"
        if not index.exists():
            index.write_text(
                "# Mutation runs\n\nOne row per run saved with `make mutation_evidence`, oldest first. Each "
                "report lists every\nsurvivor with its line before and after; the `.json` beside it holds "
                "every mutant's outcome.\n\n| Report | Commit | Scope | Mutants | Killed | Lint | Covers | Timeout | "
                "Survived | Stillborn | Score |\n|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|\n")
        n_of = {k: sum(r["status"] == k for r in results)
                for k in ("killed", "lint", "covers", "timeout", "survived", "stillborn")}
        live = len(results) - n_of["stillborn"] - sum(r["status"] == "ai_equiv" for r in results)
        score = f"{100 * (n_of['killed'] + n_of['lint'] + n_of['covers'] + n_of['timeout']) / live:.1f}%" if live else "-"
        what = (f"modules {args.modules}" if args.modules else "all modules") \
            + (f", operators {args.operators}" if args.operators else "") \
            + (f", sample {args.sample}" if args.sample else "") + (f", ids {args.ids}" if args.ids else "") \
            + (f", {args.sim_args}" if args.sim_args else "") \
            + (f", triage (audit {args.audit})" if args.triage else "")
        with index.open("a") as f:
            f.write(f"| `{stem}.txt` | {commit}{' (uncommitted changes)' if dirty else ''} | {what} | {len(results)} | "
                    f"{n_of['killed']} | {n_of['lint']} | {n_of['covers']} | {n_of['timeout']} | {n_of['survived']} | "
                    f"{n_of['stillborn']} | {score} |\n")
        print(f"evidence: {ev / stem}.txt / .json, indexed in {index}")


if __name__ == "__main__":
    main()
