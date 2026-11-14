#!/usr/bin/env python3
#
# Filename:         triage_mutants.py
#
# File Description: Runs the AI triage of mutants (ai/tasks/triage_mutants):
#                   before any mutant is simulated, an AI agent - Claude Code,
#                   run here on this machine in its non-interactive mode -
#                   reads the RTL and sorts the mutants into "plausible" (the
#                   edit can change the module's behaviour; simulate it) and
#                   "equivalent" (it cannot).
#
#                   The agent is given read access to the RTL and nothing
#                   else: its only tools are Read, Grep and Glob, the
#                   testbenches and checkers are unreadable to it, and every
#                   edit, command and network request is denied by
#                   settings_readonly.json. Its answer comes back as
#                   structured data (schema.json), not as files it writes.
#
#                   What this script does around the agent:
#                     1. lists the mutants and screens them with make lint -
#                        one that lint rejects needs no judgement
#                     2. sends the rest one module chunk at a time, with the
#                        task instructions
#                     3. checks every answer: a verdict for exactly the
#                        mutants asked about, no others; a bad answer is
#                        asked again once, then the chunk is left
#                        "untriaged" - and an untriaged mutant is simulated
#                     4. writes build/mutation/triage.json for the mutation
#                        runner (--triage), and a record of the run - each
#                        prompt and each raw response - under build/ai_runs/
#
#                   The agent's verdicts are never taken on trust: the
#                   mutation runner simulates the mutants it called
#                   equivalent too (--audit), and an "equivalent" mutant that
#                   a test kills is reported as a triage error.
#
#                   Two ways to use it:
#                     after the tests (recommended) - with --survivors, only
#                       the mutants that survived a mutation run are judged:
#                       each is a real gap (plausible) or changes nothing
#                       (equivalent). A hundred or so mutants, and exactly
#                       the ones that need a judgement.
#                     before the tests - every mutant that passes lint is
#                       judged, and the mutation run can then skip the ones
#                       called equivalent (--triage, --audit). About ten
#                       times the requests, for little saving: the plausible
#                       ones, which are most of them, are simulated anyway.
#
#                   Usage: triage_mutants.py [--survivors RESULTS.json]
#                                            [--modules a,b] [--chunk N]
#                                            [--model NAME] [--resume DIR]
#                                            [--dry-run] [--evidence]
#                     --survivors a mutation run's results.json: judge only
#                                 the mutants that survived it
#                     --dry-run   write the prompts and the exact command,
#                                 call nothing
#                     --resume    continue a run that stopped (a usage limit,
#                                 say): chunks already answered are kept
#                     --evidence  also copy the run record to
#                                 evidence/ai_runs/ and add it to the ledger
#
# Global variables: REPO, TASK, CLAUDE - see below

import argparse
import concurrent.futures
import datetime
import json
import os
import pathlib
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "tools" / "mutation"))
import run_mutation as R  # noqa: E402

# REPO: the repository root
REPO = R.REPO
# TASK: the task folder - instructions and output schema
TASK = HERE.parent / "tasks" / "triage_mutants"
# CLAUDE: the Claude Code command (override with the CLAUDE environment variable)
CLAUDE = os.environ.get("CLAUDE", "claude")


def command(model):

    """
    Purpose: The exact Claude Code command for one chunk. Read-only tools,
             no MCP servers, anything that would ask for permission denied,
             and the answer forced into the task's schema. The prompt goes
             in on stdin.
    """
    cmd = [CLAUDE, "-p",
           "--tools", "Read,Grep,Glob",
           "--strict-mcp-config",
           "--permission-mode", "dontAsk",
           "--settings", str(HERE / "settings_readonly.json"),
           "--output-format", "json",
           "--json-schema", json.dumps(json.loads((TASK / "schema.json").read_text()))]
    if model:
        cmd += ["--model", model]
    return cmd


def prompt_for(unit, file, chunk):

    """
    Purpose: The prompt for one chunk: the task instructions, the module,
             and the mutants as JSON.
    """
    items = []
    for m in chunk:
        before, after = R.line_pair(m)
        items.append({"id": m.id, "line": m.line, "operator": m.operator, "description": m.description,
                      "before": before, "after": after})
    return (TASK / "TASK.md").read_text() + f"\n## The module\n\n`{unit}`, in `{file}`.\n\n## The mutants\n\n" \
        + "```json\n" + json.dumps(items, indent=1) + "\n```\n"


def read_response(text):

    """
    Purpose: The result object of a Claude Code JSON response, or None.
    """
    try:
        data = json.loads(text)
    except ValueError:
        return None
    if isinstance(data, list):
        data = next((d for d in reversed(data) if isinstance(d, dict) and d.get("type") == "result"), None)
    return data if isinstance(data, dict) else None


def check(result, chunk):

    """
    Purpose: Validate one answer against the chunk it was asked about.
             Returns (verdicts by id, problem) - problem is None when the
             answer is usable.
    """
    if result is None:
        return {}, "the response was not JSON"
    if result.get("is_error"):
        return {}, f"the run reported an error: {str(result.get('result', ''))[:200]}"
    out = result.get("structured_output")
    if not isinstance(out, dict) or not isinstance(out.get("verdicts"), list):
        return {}, "no structured verdicts in the response"
    want = {m.id for m in chunk}
    got = {}
    for v in out["verdicts"]:
        if v.get("id") in got:
            return {}, f"two verdicts for {v.get('id')}"
        got[v.get("id")] = v
    if set(got) != want:
        missing, extra = sorted(want - set(got)), sorted(set(got) - want)
        return {}, f"verdicts do not match the mutants asked: {len(missing)} missing, {len(extra)} unknown"
    for v in got.values():
        if v.get("verdict") not in ("plausible", "equivalent") or v.get("confidence") not in ("high", "medium", "low") \
                or not str(v.get("reason", "")).strip():
            return {}, f"malformed verdict for {v.get('id')}"
    return got, None


def main():

    """
    Purpose: Screen, chunk, ask, check, and write triage.json and the run
             record.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--survivors")
    ap.add_argument("--modules")
    ap.add_argument("--chunk", type=int, default=40)
    ap.add_argument("--model")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2, help="parallel lint screens")
    ap.add_argument("--resume")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--evidence", action="store_true")
    args = ap.parse_args()

    ms = R.all_mutants()
    if args.modules:
        want = set(args.modules.split(","))
        ms = [m for m in ms if m.unit in want]
    stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    task = "judge_survivors" if args.survivors else "triage_mutants"
    run = pathlib.Path(args.resume) if args.resume else REPO / "verif_automation" / "build" / "ai_runs" / f"{stamp}_{task}"
    (run / "chunks").mkdir(parents=True, exist_ok=True)

    if args.survivors:
        # after the tests: only the mutants that survived that run
        survived = {r["id"] for r in json.loads(pathlib.Path(args.survivors).read_text())["results"]
                    if r["status"] == "survived"}
        clean = [m for m in ms if m.id in survived]
        missing = survived - {m.id for m in clean}
        if missing and not args.modules:
            sys.exit(f"{len(missing)} survivors of that run are not mutants of the RTL as it is now "
                     f"(for example {sorted(missing)[0]}) - the RTL has changed since; run the mutation again")
        ms = clean
        print(f"{len(clean)} survivors of {args.survivors} go to judgement")
    else:
        # before the tests: lint screen - only the mutants lint accepts need a judgement
        print(f"screening {len(ms)} mutants with make lint ...", flush=True)
        work = run / "work"
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            screened = list(pool.map(lambda m: R.run_one(m, work, 0, False, simulate=False)[0], ms))
        shutil.rmtree(work, ignore_errors=True)
        clean = [m for m, s in zip(ms, screened) if s == "clean"]
        print(f"{len(clean)} pass lint and go to triage; {len(ms) - len(clean)} are already caught or not legal")

    # 2. chunks: one module at a time, at most --chunk mutants each
    chunks = []
    by_unit = {}
    for m in clean:
        by_unit.setdefault((m.unit, m.file), []).append(m)
    for (unit, file), group in by_unit.items():
        for k in range(0, len(group), args.chunk):
            chunks.append((unit, file, group[k:k + args.chunk]))

    cmd = command(args.model)
    (run / "command.txt").write_text(" ".join(c if " " not in c and "{" not in c else repr(c) for c in cmd)
                                     + "   < chunks/NN_prompt.txt\n")
    verdicts, log, stopped = {}, [], None
    for n, (unit, file, chunk) in enumerate(chunks, 1):
        tag = f"{n:03d}_{unit}"
        prompt = prompt_for(unit, file, chunk)
        (run / "chunks" / f"{tag}_prompt.txt").write_text(prompt)
        if args.dry_run:
            log.append((tag, len(chunk), "dry run", ""))
            continue
        resp_file = run / "chunks" / f"{tag}_response.json"
        got, problem = ({}, "not asked yet")
        if resp_file.exists():                      # --resume: keep an answer already given
            got, problem = check(read_response(resp_file.read_text()), chunk)
        attempts = 0
        while problem and attempts < 2 and not stopped:
            attempts += 1
            print(f"[{n}/{len(chunks)}] {unit}: {len(chunk)} mutants (attempt {attempts}) ...", flush=True)
            try:
                p = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=REPO, timeout=3600)
            except FileNotFoundError:
                sys.exit(f"'{CLAUDE}' not found - install Claude Code and log in, or set CLAUDE=/path/to/claude")
            except subprocess.TimeoutExpired:
                problem = "no answer within an hour"
                continue
            resp_file.write_text(p.stdout)
            got, problem = check(read_response(p.stdout), chunk)
            text = (p.stdout + p.stderr).lower()
            if problem and any(w in text for w in ("usage limit", "rate limit", "limit reached", "not logged in",
                                                   "authentication")):
                stopped = f"stopped at chunk {tag}: {problem} - run again with --resume {run}"
        if problem:
            log.append((tag, len(chunk), "untriaged", problem))
            for m in chunk:
                verdicts[m.id] = {"verdict": "plausible", "confidence": "low",
                                  "reason": "untriaged: " + problem, "chunk": tag, "untriaged": True}
        else:
            eq = sum(v["verdict"] == "equivalent" and v["confidence"] == "high" for v in got.values())
            log.append((tag, len(chunk), "ok", f"{eq} judged equivalent (high confidence)"))
            for mid, v in got.items():
                verdicts[mid] = {"verdict": v["verdict"], "confidence": v["confidence"],
                                 "reason": " ".join(str(v["reason"]).split()), "chunk": tag}
        if stopped:
            break

    # 3. results
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                            text=True).stdout.strip() or "unknown"
    models = set()
    for f in (run / "chunks").glob("*_response.json"):
        r = read_response(f.read_text()) or {}
        models |= set((r.get("modelUsage") or {}).keys())
    n_eq = sum(v["verdict"] == "equivalent" and v["confidence"] == "high" for v in verdicts.values())
    n_un = sum(bool(v.get("untriaged")) for v in verdicts.values())
    header = {"date": datetime.date.today().isoformat(), "commit": commit, "task": task,
              "survivors_of": args.survivors or "",
              "agent": "Claude Code (claude -p), read-only", "models": sorted(models),
              "mutants_listed": len(ms), "sent_to_triage": len(clean), "judged": len(verdicts) - n_un,
              "equivalent_high_confidence": n_eq, "untriaged": n_un, "complete": not stopped and not args.dry_run}
    title = "Judgement of surviving mutants" if args.survivors else "Triage of mutants"
    summary = [f"# {title} - {header['date']} - commit {commit}", "",
               f"Agent: {header['agent']}" + (f"; model(s): {', '.join(sorted(models))}" if models else ""),
               f"Mutants listed: {len(ms)}; passed lint and sent to triage: {len(clean)}; judged: "
               f"{header['judged']}; judged equivalent with high confidence: {n_eq}; untriaged: {n_un}", "",
               "| Chunk | Mutants | Outcome | Note |", "|---|---:|---|---|"]
    summary += [f"| {t} | {k} | {o} | {note} |" for t, k, o, note in log]
    if stopped:
        summary += ["", f"**Incomplete:** {stopped}"]
    summary += ["", "## Judged equivalent (high confidence)", ""]
    summary += [f"- `{mid}`: {v['reason']}" for mid, v in sorted(verdicts.items())
                if v["verdict"] == "equivalent" and v["confidence"] == "high"] or ["None."]
    if args.survivors:
        summary += ["", "## Judged a real gap - the edit changes behaviour and no test noticed", ""]
        summary += [f"- `{mid}` ({v['confidence']}): {v['reason']}" for mid, v in sorted(verdicts.items())
                    if not (v["verdict"] == "equivalent" and v["confidence"] == "high")] or ["None."]
    (run / "summary.md").write_text("\n".join(summary) + "\n")
    if not args.dry_run:
        out = REPO / "verif_automation" / "build" / "mutation" / \
            ("survivors_judged.json" if args.survivors else "triage.json")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"header": header, "verdicts": verdicts}, indent=1) + "\n")
        shutil.copy(out, run / "triage.json")
        print(f"triage: {out}")
    print("\n".join(summary[:4]))
    print(f"run record: {run}")
    if stopped:
        print(stopped)
    if args.evidence and not args.dry_run:
        save_evidence(run, header, n_eq, n_un)


def save_evidence(run, header, n_eq, n_un):

    """
    Purpose: Copy the run record into evidence/ai_runs/ and add a row to the
             ledger there (creating it on the first run).
    """
    ev = REPO / "verif_automation" / "evidence" / "ai_runs"
    ev.mkdir(parents=True, exist_ok=True)
    name, n = f"{header['date']}_{header['task']}", 1
    while (ev / (name if n == 1 else f"{name}_{n}")).exists():
        n += 1
    dest = ev / (name if n == 1 else f"{name}_{n}")
    shutil.copytree(run, dest, ignore=shutil.ignore_patterns("work"))
    ledger = ev / "ledger.md"
    if not ledger.exists():
        ledger.write_text(
            "# AI run ledger\n\nOne row per run of the agent, oldest first. Each run's full record - the "
            "instructions sent, every\nraw response, the result - is in the folder named in its row.\n\n"
            "| Run | Date | Commit | Task | Given | Produced | Gate | Verdict |\n|---|---|---|---|---|---|---|---|\n")
    rows = sum(1 for line in ledger.read_text().splitlines() if line.startswith("| A"))
    with ledger.open("a") as f:
        gate = "the designer's review of each verdict" if header["task"] == "judge_survivors" else \
            "the mutation run's audit: every mutant judged equivalent that a test kills is a triage error"
        f.write(f"| A{rows + 1} | {header['date']} | {header['commit']} | {header['task']} (`{dest.name}/`) | "
                f"read access to rtl-systemverilog/; {header['sent_to_triage']} mutants | verdicts for "
                f"{header['judged']} ({n_eq} equivalent with high confidence, {n_un} untriaged) | {gate} | "
                f"pending |\n")
    print(f"evidence: {dest}, ledger {ledger}")


if __name__ == "__main__":
    main()
