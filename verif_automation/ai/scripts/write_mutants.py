#!/usr/bin/env python3
#
# Filename:         write_mutants.py
#
# File Description: Runs the AI step that writes mutants (ai/tasks/
#                   write_mutants). The mechanical operators change one token
#                   at a time; they cannot make a fault that needs the
#                   design's meaning - a field captured on the wrong event, a
#                   reject rule that forgets one register. An AI agent -
#                   Claude Code, run here on this machine in its
#                   non-interactive mode - reads one module and writes such
#                   faults, each as a few lines replaced by a few others.
#
#                   The agent only proposes. It has read access to the RTL
#                   and the documents and nothing else: no edits, no
#                   commands, no network, and the testbenches and checkers
#                   are unreadable to it. Its answer comes back as structured
#                   data (schema.json). This script then puts every proposal
#                   through a gate, and only what passes is stored:
#                     1. the lines it replaces are in the file, at one place
#                     2. it changes at most MAX_CHANGED lines, inside the
#                        module's body - not its ports or parameters
#                     3. it changes the code, not only comments or spacing
#                     4. it is not a mutant a mechanical operator already
#                        makes, nor one already stored
#                     5. it is legal code and make lint accepts it - so only
#                        a test can catch it
#                   An accepted mutant is added to ai/mutants/<module>.json.
#                   From there the mutation runner loads it beside the
#                   mechanical ones, as operator AIM. Nothing here runs a
#                   simulation, and nothing judges whether a mutant is
#                   killed: that is the mutation run.
#
#                   Running it again for a module adds to what is stored: the
#                   agent is shown the mutants already written and asked for
#                   different ones. To drop a mutant, delete its entry from
#                   the module's file in ai/mutants/.
#
#                   Usage: write_mutants.py [--modules a,b] [--count N]
#                                           [--model NAME] [--jobs N]
#                                           [--dry-run] [--no-record]
#                     --modules   the modules to write for (default: all)
#                     --count     mutants asked for per module (default:
#                                 COUNTS - more for the large modules)
#                     --dry-run   write the prompts and the exact command,
#                                 call nothing
#                     --no-record do not keep this run as evidence (a trial
#                                 of the tool). By default the run record is
#                                 copied to evidence/ai_runs/, a row added to
#                                 the ledger there, and the run - its
#                                 accepted mutants and every rejected
#                                 proposal - added to each module's record
#                                 in evidence/mutation/
#
# Global variables: REPO, TASK, STORE, COUNTS, DEFAULT_COUNT, MAX_BEFORE,
#                   MAX_AFTER, MAX_CHANGED, MAX_CONTEXT, PER_REQUEST, NUMBERED
#                   - see below

import argparse
import concurrent.futures
import datetime
import difflib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent.parent / "tools" / "mutation"))
sys.path.insert(0, str(HERE.parent.parent / "tools" / "common"))
import mutants as M  # noqa: E402
import record as REC  # noqa: E402
import run_mutation as R  # noqa: E402
import svparse  # noqa: E402
import triage_mutants as T  # noqa: E402

# REPO: the repository root
REPO = R.REPO
# TASK: the task folder - instructions and output schema
TASK = HERE.parent / "tasks" / "write_mutants"
# STORE: where accepted mutants are kept, one file per module
STORE = R.AI_STORE
# COUNTS / DEFAULT_COUNT: mutants asked for per module in one run - most for
#                         the two modules that hold the host interface
COUNTS = {"reg_file": 40, "spi_slave": 30, "pmic_top": 15, "supervisor": 12}
DEFAULT_COUNT = 6
# MAX_BEFORE / MAX_AFTER / MAX_CHANGED: the size of one edit - lines replaced,
#                         lines put there, and lines that may differ
MAX_BEFORE, MAX_AFTER, MAX_CHANGED = 12, 16, 6
# MAX_CONTEXT: unchanged lines added around a stored edit until its text
#              stands at only one place in the file
MAX_CONTEXT = 6
# PER_REQUEST: the most mutants asked for in one request. A module asked for
#              more gets several requests, each shown what the earlier ones
#              produced - smaller answers, and less repetition
PER_REQUEST = 20
# NUMBERED: a line quoted with a viewer's line number in front of it
NUMBERED = re.compile(r"^\s*\d+\s*(?:\t|\u2192|\|)\s?")


def body_lines(path):

    """
    Purpose: For each module in a file, the first and last 1-based lines of
             its body: the line after the ';' that closes its port list, and
             the line before endmodule.
    """
    src = svparse.parse(str(path))
    toks = src.tokens
    out = {}
    for unit in src.units:
        if unit.kind != "module":
            continue
        end = next(k for k in range(unit.first + 2, unit.last + 1)
                   if toks[k].text == ";" and (toks[k - 1].text == ")" or k == unit.first + 2))
        out[unit.name] = (toks[end].line + 2, toks[unit.last].line)
    return out


def prompt_for(unit, file, count, mechanical, stored):

    """
    Purpose: The prompt for one module: the task instructions, the module
             and the number asked for, the mechanical operators, and the
             mutants already written for it.
    """
    ops = "\n".join(f"- {op}: {what}" for op, what in M.OPERATORS.items() if op != M.AI_OPERATOR)
    have = "\n".join(f"- line {e['line']}: {e['description']}" for e in stored) or "None yet."
    return (TASK / "TASK.md").read_text() + (
        f"\n## The module\n\n`{unit}`, in `{file}`. Write up to {count} mutants.\n"
        f"\n## The mechanical operators\n\nThese are already made for this module ({mechanical} mutants). "
        f"Do not write an edit that one of them makes.\n\n{ops}\n"
        f"\n## Mutants already written for this module\n\n{have}\n")


def proposals_of(result):

    """
    Purpose: The proposed mutants of one response. Returns (list, problem) -
             problem is None when the response is usable.
    """
    if result is None:
        return [], "the response was not JSON"
    if result.get("is_error"):
        return [], f"the run reported an error: {str(result.get('result', ''))[:200]}"
    out = T.structured(result)
    if out is None or not isinstance(out.get("mutants"), list):
        return [], "no structured mutants in the response"
    return out["mutants"], None


def shape(p, unit, rel, text, body, taken):

    """
    Purpose: Gate checks 1 to 4 for one proposal - everything short of lint.
             taken maps the code key of every mutant already made (the
             mechanical ones, the stored ones, the ones accepted earlier in
             this run) to its id. Returns (entry, mutant, key, problem):
             problem is None when the proposal passes, and entry is then the
             edit as it will be stored, with unchanged lines added around it
             until its text stands at one place in the file.
    """
    def lines_of(x):
        return [part.rstrip("\r") for item in x for part in str(item).split("\n")] if isinstance(x, list) else None

    before, after = lines_of(p.get("before")), lines_of(p.get("after"))
    if not before or after is None or not any(b.strip() for b in before):
        return None, None, None, "no lines to replace were given"
    if len(before) > MAX_BEFORE or len(after) > MAX_AFTER:
        return None, None, None, f"too large: replaces {len(before)} lines with {len(after)}"
    line = p.get("line") if isinstance(p.get("line"), int) else 0
    hits = M.locate(text, before, line)
    if not hits and all(NUMBERED.match(b) for b in before if b.strip()):
        # lines quoted with the line numbers a file viewer shows: take the numbers off
        before = [NUMBERED.sub("", b) for b in before]
        after = [NUMBERED.sub("", a) for a in after]
        hits = M.locate(text, before, line)
    if not hits:
        return None, None, None, "the lines it replaces are not in the file"
    if len(hits) > 1 and line - 1 not in hits:
        return None, None, None, f"the lines it replaces stand in {len(hits)} places and 'line' picks none of them"
    at = line - 1 if line - 1 in hits else hits[0]
    changed = sum(max(i2 - i1, j2 - j1) for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
        None, [b.strip() for b in before], [a.strip() for a in after], autojunk=False).get_opcodes() if tag != "equal")
    if changed == 0:
        return None, None, None, "the lines are the same before and after"
    if changed > MAX_CHANGED:
        return None, None, None, f"changes {changed} lines; at most {MAX_CHANGED}"

    # unchanged lines added around the edit until its text is at one place only
    raw = text.split("\n")
    added = 0
    while len(M.locate(text, before)) > 1 and added < MAX_CONTEXT:
        if at > 0:
            at -= 1
            before, after = [raw[at]] + before, [raw[at]] + after
        elif at + len(before) < len(raw):
            before, after = before + [raw[at + len(before)]], after + [raw[at + len(before)]]
        added += 1
    if len(M.locate(text, before)) > 1:
        return None, None, None, "the lines it replaces cannot be told from another place in the file"

    entry = {"key": 0, "line": at + 1, "category": str(p.get("category", "other")),
             "description": " ".join(str(p.get("description", "")).split()),
             "reason": " ".join(str(p.get("reason", "")).split()), "before": before, "after": after}
    if not entry["description"]:
        return None, None, None, "no description"
    m = M.written_mutant(entry, unit, rel, text, at=at)
    if m is None:
        return None, None, None, "the lines it replaces are not in the file"
    first, last = body.get(unit, (0, 0))
    if not (first <= m.line and at + len(before) <= last):
        return None, None, None, "edits the module's ports or parameters, or lines outside the module"
    key = M.code_key(m.apply(text))
    if key == M.code_key(text):
        return None, None, None, "changes only comments or spacing"
    if key in taken:
        return None, None, None, f"the same edit as {taken[key]}"
    return entry, m, key, None


def main():

    """
    Purpose: For each module: ask, gate every proposal, store what passes,
             and write the run record.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--modules")
    ap.add_argument("--count", type=int)
    ap.add_argument("--model")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2, help="parallel lint screens")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-record", action="store_true")
    args = ap.parse_args()
    keep = not args.no_record and not args.dry_run
    kept_in = T.evidence_dest("write_mutants") if keep else None

    mechanical = R.mechanical_mutants()
    modules, _ = M.design_info(REPO / "rtl-systemverilog")
    files = {m.unit: m.file for m in mechanical if m.unit in modules}
    units = sorted(files, key=lambda u: (-COUNTS.get(u, DEFAULT_COUNT), u))
    if args.modules:
        want = args.modules.split(",")
        unknown = [u for u in want if u not in files]
        if unknown:
            sys.exit(f"not a module of the RTL: {', '.join(unknown)}")
        units = [u for u in units if u in want]

    stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    run = REPO / "verif_automation" / "build" / "ai_runs" / f"{stamp}_write_mutants"
    (run / "chunks").mkdir(parents=True, exist_ok=True)
    cmd = T.command(args.model, TASK)
    (run / "command.txt").write_text(" ".join(c if " " not in c and "{" not in c else repr(c) for c in cmd)
                                     + "   < chunks/NN_prompt.txt\n")
    STORE.mkdir(parents=True, exist_ok=True)

    log, rejected_all, stopped = [], [], None
    asked = proposed = accepted_n = 0
    for n, unit in enumerate(units, 1):
        rel = files[unit]
        text = M.source_text(str(REPO / rel))
        store_file = STORE / f"{unit}.json"
        count = args.count or COUNTS.get(unit, DEFAULT_COUNT)
        mech = [m for m in mechanical if m.file == rel]
        body = body_lines(REPO / rel)
        # the code of every mutant already made: no proposal may repeat one
        taken = {M.code_key(m.apply(text)): m.id for m in mech} if not args.dry_run else {}

        unit_asked, unit_new, unit_rejected, unit_models = 0, [], [], set()
        # a module asked for more than PER_REQUEST gets several requests,
        # each shown what the earlier ones produced
        for part, want in enumerate([PER_REQUEST] * (count // PER_REQUEST) + [count % PER_REQUEST] * bool(
                count % PER_REQUEST), 1):
            tag = f"{n:03d}_{unit}_{part}"
            stored = json.loads(store_file.read_text())["mutants"] if store_file.exists() else []
            asked += want
            prompt = prompt_for(unit, rel, want, sum(m.unit == unit for m in mech), stored)
            (run / "chunks" / f"{tag}_prompt.txt").write_text(prompt)
            if args.dry_run:
                log.append((tag, want, "dry run", "", ""))
                continue

            props, problem, attempts = [], "not asked yet", 0
            while problem and attempts < 2 and not stopped:
                attempts += 1
                print(f"[{n}/{len(units)}] {unit}: asking for {want} mutants (request {part}, attempt {attempts}) ...",
                      flush=True)
                try:
                    p = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=REPO, timeout=3600)
                except FileNotFoundError:
                    sys.exit(f"'{T.CLAUDE}' not found - install Claude Code and log in, or set "
                             "CLAUDE=/path/to/claude")
                except subprocess.TimeoutExpired:
                    problem = "no answer within an hour"
                    continue
                (run / "chunks" / f"{tag}_response.json").write_text(p.stdout)
                answer = T.read_response(p.stdout)
                unit_models |= set(((answer or {}).get("modelUsage") or {}).keys())
                props, problem = proposals_of(answer)
                out_text = (p.stdout + p.stderr).lower()
                if problem and any(w in out_text for w in ("usage limit", "rate limit", "limit reached",
                                                           "not logged in", "authentication")):
                    stopped = f"stopped at {tag}: {problem} - run again for the remaining modules (MODULE=)"
            if problem:
                log.append((tag, want, "no answer", "", problem))
                break

            # the gate: checks 1-4 on each proposal, then make lint on the ones that pass
            for e in stored:
                m = M.written_mutant(e, unit, rel, text)
                if m is not None:
                    taken[M.code_key(m.apply(text))] = m.id
            next_key = max((e["key"] for e in stored), default=0) + 1
            checked, passing = [], []
            for k, prop in enumerate(props):
                entry, m, key, why = shape(prop, unit, rel, text, body, taken)
                checked.append({"proposal": prop, "accepted": False, "why": why})
                if why is None and key is not None:
                    taken[key] = f"proposal {k + 1} of the same answer"
                    passing.append((k, entry, m, key))
            work = R.SCRATCH / run.name / "work"
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
                screened = list(pool.map(lambda item: R.run_one(item[2], work / f"{unit}_{item[0]}", 0, False,
                                                                simulate=False), passing))
            shutil.rmtree(R.SCRATCH / run.name, ignore_errors=True)
            new = []
            for (k, entry, m, key), (status, _, detail, _) in zip(passing, screened):
                if status != "clean":
                    del taken[key]
                    checked[k]["why"] = {"lint": "make lint already catches it", "stillborn": "not legal code"}.get(
                        status, "could not be screened") + f": {detail[:160]}"
                    continue
                entry["key"], next_key = next_key, next_key + 1
                entry["run"] = kept_in.name if kept_in else run.name
                checked[k].update(accepted=True, why=None, id=f"{unit}.{m.line}.{M.AI_OPERATOR}.{entry['key']}")
                new.append(entry)
                unit_new.append({**entry, "id": checked[k]["id"]})
            (run / "chunks" / f"{tag}_checked.json").write_text(json.dumps(checked, indent=1) + "\n")
            if new:
                store_file.write_text(json.dumps({"unit": unit, "file": rel, "mutants": stored + new}, indent=1)
                                      + "\n")
            proposed += len(props)
            accepted_n += len(new)
            unit_asked += want
            for c in checked:
                if not c["accepted"]:
                    what = " ".join(str(c["proposal"].get("description", "")).split())
                    rejected_all.append((unit, what[:90], c["why"]))
                    unit_rejected.append({"description": what, "why": c["why"]})
            log.append((tag, want, "ok",
                        f"{len(props)} proposed, {len(new)} accepted, {len(props) - len(new)} rejected", ""))
            print(f"    {len(props)} proposed, {len(new)} accepted, {len(props) - len(new)} rejected", flush=True)
            if not props:
                break               # the agent has no more to offer for this module
        if kept_in is not None and (unit_new or unit_rejected):
            # this run added to the module's record: its accepted mutants and every rejected proposal
            REC.add_written(unit, rel, unit_new, unit_rejected, unit_asked, sorted(unit_models),
                            f"ai_runs/{kept_in.name}")
        if stopped:
            break

    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                            text=True).stdout.strip() or "unknown"
    models = set()
    for f in (run / "chunks").glob("*_response.json"):
        models |= set(((T.read_response(f.read_text()) or {}).get("modelUsage") or {}).keys())
    header = {"date": datetime.date.today().isoformat(), "commit": commit, "task": "write_mutants",
              "agent": "Claude Code (claude -p), read-only", "models": sorted(models), "modules": len(units),
              "asked_for": asked, "proposed": proposed, "accepted": accepted_n,
              "complete": not stopped and not args.dry_run}
    summary = [f"# Mutants written by the AI step - {header['date']} - commit {commit}", "",
               f"Agent: {header['agent']}" + (f"; model(s): {', '.join(sorted(models))}" if models else ""),
               f"Modules: {len(units)}; mutants asked for: {asked}; proposed: {proposed}; accepted by the gate: "
               f"{accepted_n}; rejected: {proposed - accepted_n}", "",
               "| Request | Asked for | Outcome | Result | Note |", "|---|---:|---|---|---|"]
    summary += [f"| {t} | {c} | {o} | {res} | {note} |" for t, c, o, res, note in log]
    if stopped:
        summary += ["", f"**Incomplete:** {stopped}"]
    summary += ["", "## Rejected by the gate", ""]
    summary += [f"- `{u}`: {d} - **{why}**" for u, d, why in rejected_all] or ["None."]
    (run / "summary.md").write_text("\n".join(summary) + "\n")
    print("\n".join(summary[:4]))
    print(f"run record: {run}")
    if stopped:
        print(stopped)
    if not args.dry_run:
        print(f"stored in: {STORE}   list them: make mutants OPERATORS={M.AI_OPERATOR}")
    if keep:
        print("recorded in: " + ", ".join(str(REC.DIR / f"{u}.md") for u in units
                                          if (REC.DIR / f"{u}.json").exists()))
        T.save_evidence(run, header,
                        f"read access to rtl-systemverilog/ and the documents; {len(units)} modules, "
                        f"{asked} mutants asked for",
                        f"{proposed} mutants proposed; {accepted_n} accepted, {proposed - accepted_n} rejected",
                        "deterministic: the replaced lines exist at one place, the edit is small and changes the "
                        "code, it is not a mechanical or an earlier mutant, and it is legal code that make lint "
                        "accepts. Whether a test kills it is the mutation run", kept_in)


if __name__ == "__main__":
    main()
