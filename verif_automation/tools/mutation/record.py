#!/usr/bin/env python3
#
# Filename:         record.py
#
# File Description: The mutation record of each module: one file per module
#                   that everything about its mutants is added to, and that
#                   nothing is ever removed from.
#
#                   evidence/mutation/<module>.json holds, for one module:
#                     runs     every step ever run on it, in order - the AI
#                              writing mutants, a mutation run, the AI
#                              judging survivors, a decision by the designer
#                              - with its date, commit and result
#                     mutants  every mutant ever run or written, each with
#                              the outcome of every run it was in, every
#                              judgement the AI gave it, and every decision
#                              the designer recorded
#                   Each step appends. A second AI run adds its mutants and
#                   its rejected proposals beside the first run's; a second
#                   mutation run adds a second outcome to each mutant; the
#                   earlier ones stay. evidence/mutation/<module>.md is the
#                   same record written out to be read, and
#                   evidence/mutation/README.md lists every module's present
#                   state. Both are rewritten from the .json each time.
#
#                   A mutant is known by what it is - its operator and the
#                   line before and after the edit - not by its line number,
#                   so its history follows it when the lines above it move.
#                   An AI-written mutant is known by its key in ai/mutants/.
#                   A mutant the generator no longer makes (the RTL changed)
#                   is kept, marked retired, and left out of the present
#                   score.
#
#                   The present state of a mutant is its newest outcome. The
#                   present score is over the present states; every earlier
#                   score is in the run history.
#
#                   Usage: record.py show [--modules a,b]
#                          record.py decide --ids ID,ID --as equivalent|accepted|gap
#                                           --why "the reason"
#                          record.py render
#                     show    print each module's present state
#                     decide  record the designer's decision on survivors:
#                               equivalent  the edit changes nothing that can
#                                           be observed
#                               accepted    a real difference left open on
#                                           purpose
#                               gap         a real gap, still to be closed
#                                           by a property or test
#                     render  rewrite every .md and the index from the .json
#
# Global variables: REPO, DIR, CAUGHT, DECISIONS - see below

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys

# REPO: the repository root
REPO = pathlib.Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True,
                                   cwd=pathlib.Path(__file__).parent).stdout.strip()
                    or pathlib.Path(__file__).resolve().parents[3])
# DIR: where the records are kept
DIR = REPO / "verif_automation" / "evidence" / "mutation"
# CAUGHT: the outcomes that count as caught
CAUGHT = ("killed", "lint", "covers", "timeout")
# DECISIONS: what the designer can decide about a survivor
DECISIONS = {"equivalent": "changes nothing that can be observed",
             "accepted": "a real difference, left open on purpose",
             "gap": "a real gap, still to be closed"}


def load(module, file=""):
    """Purpose: a module's record, or a new empty one."""
    path = DIR / f"{module}.json"
    if path.exists():
        return json.loads(path.read_text())
    return {"module": module, "file": file, "runs": [], "mutants": {}}


def save(rec):
    """Purpose: write a module's record, its readable copy, and the index."""
    DIR.mkdir(parents=True, exist_ok=True)
    (DIR / f"{rec['module']}.json").write_text(json.dumps(rec, indent=1) + "\n")
    (DIR / f"{rec['module']}.md").write_text(render(rec))
    write_index()


def stamp():
    """Purpose: the date, time and commit of a step, for its run entry."""
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                            text=True).stdout.strip() or "unknown"
    dirty = subprocess.run(["git", "status", "--porcelain", "--", "rtl-systemverilog", "sva", "tb"], cwd=REPO,
                           capture_output=True, text=True).stdout.strip()
    now = datetime.datetime.now()
    return {"date": now.strftime("%Y-%m-%d"), "time": now.strftime("%H:%M"), "commit": commit,
            "uncommitted": bool(dirty)}


def keys_of(items, ai_operator="AIM"):

    """
    Purpose: The lasting key of each mutant in items - dicts with id,
             operator, description, before and after, in file order. An
             AI-written mutant: "AIM.<its store key>". Any other: a hash of
             what the edit is, and "#n" for the n-th mutant that is the same
             edit of the same text (two identical lines both deleted, say).
             Line numbers are left out, so a key outlives the lines moving.
             Returns {id: key}.
    """
    out, seen = {}, {}
    for it in items:
        if it["operator"] == ai_operator:
            out[it["id"]] = f"{ai_operator}.{it['id'].rsplit('.', 1)[1]}"
            continue
        what = re.sub(r"\bline \d+", "line", it["description"])
        base = hashlib.sha1("\0".join((it["operator"], what, it["before"], it["after"])).encode()).hexdigest()[:10]
        seen[base] = seen.get(base, 0) + 1
        out[it["id"]] = f"{base}#{seen[base]}"
    return out


def new_run(rec, kind, **fields):
    """Purpose: append one step to a record's history and return its number."""
    n = len(rec["runs"]) + 1
    rec["runs"].append({"n": n, "kind": kind, **stamp(), **fields})
    return n


def entry_for(rec, key, item):

    """
    Purpose: The record's entry for a mutant, made if it is new, with the
             fields that say where it is now brought up to date.
    """
    e = rec["mutants"].setdefault(key, {"outcomes": [], "judgements": [], "decisions": []})
    for f in ("id", "operator", "line", "description", "before", "after"):
        if f in item:
            e[f] = item[f]
    e.pop("retired", None)
    return e


def state(e):
    """Purpose: a mutant's present state - its newest outcome that is not a tool error."""
    if e.get("retired"):
        return "retired"
    for o in reversed(e["outcomes"]):
        if o["status"] != "error":
            return o["status"]
    return "error" if e["outcomes"] else "not run"


def decision(e):
    """Purpose: the designer's newest decision on a mutant, or None."""
    return e["decisions"][-1] if e["decisions"] else None


def counts(rec, only=None):

    """
    Purpose: The present numbers of a record: mutants by state, the raw
             score, and the survivors by decision. only filters the entries
             (a function of the entry).
    """
    c = {k: 0 for k in ("killed", "lint", "covers", "timeout", "survived", "stillborn", "error", "not run",
                        "ai_equiv", "retired")}
    d = {"equivalent": 0, "accepted": 0, "gap": 0, "undecided": 0}
    for e in rec["mutants"].values():
        if only and not only(e):
            continue
        s = state(e)
        c[s] = c.get(s, 0) + 1
        if s == "survived":
            d[(decision(e) or {}).get("decision", "undecided")] += 1
    caught = sum(c[k] for k in CAUGHT)
    live = caught + c["survived"]
    c["mutants"] = sum(v for k, v in c.items() if k != "retired")
    c["score"] = f"{100 * caught / live:.1f}%" if live else "-"
    # with the survivors the designer has explained away taken out
    left = live - d["equivalent"] - d["accepted"]
    c["explained_score"] = f"{100 * caught / left:.1f}%" if left else "-"
    return c, d


def add_mutation(results, every, selection, baseline, seed, sim_args):

    """
    Purpose: Add one mutation run to the record of every module it touched.
             results are the run's result dicts; every is the same dicts for
             every mutant the generator makes now (for the keys, and to
             retire what is gone); selection says how the run was narrowed
             (None for a module's whole set). Returns the records' paths.
    """
    by_unit = {}
    for r in results:
        by_unit.setdefault(r["unit"], []).append(r)
    paths = []
    for unit, rs in sorted(by_unit.items()):
        rec = load(unit, rs[0]["file"])
        rec["file"] = rs[0]["file"]
        current = [m for m in every if m["unit"] == unit]
        keys = keys_of(current)
        n_of = {k: sum(r["status"] == k for r in rs) for k in ("killed", "lint", "covers", "timeout", "survived",
                                                               "stillborn", "error", "ai_equiv")}
        live = sum(n_of[k] for k in CAUGHT) + n_of["survived"]
        n = new_run(rec, "mutation", scope=selection or "every mutant of the module", mutants=len(rs),
                    counts={k: v for k, v in n_of.items() if v},
                    score=f"{100 * sum(n_of[k] for k in CAUGHT) / live:.1f}%" if live else "-",
                    seed=seed, sim_args=" ".join(sim_args), baseline=baseline)
        for r in rs:
            e = entry_for(rec, keys[r["id"]], r)
            o = {"run": n, "status": r["status"]}
            if r.get("detail"):
                o["detail"] = r["detail"]
            if r.get("killed_by"):
                k = r["killed_by"]
                o["killed_by"] = {"assertions": k["assertions"][:8], "tests": k["tests"][:8], "checks": k["checks"]}
            e["outcomes"].append(o)
        if not selection:           # the whole set was run: what the generator no longer makes is retired
            now = set(keys.values())
            for key, e in rec["mutants"].items():
                if key not in now and not e.get("retired"):
                    e["retired"] = n
        save(rec)
        paths.append(DIR / f"{unit}.md")
    return paths


def add_written(unit, file, accepted, rejected, asked, models, run_record):

    """
    Purpose: Add one run of the AI writing mutants to a module's record:
             the accepted mutants as new entries, not yet run, and every
             rejected proposal with the check it failed.
    """
    rec = load(unit, file)
    rec["file"] = file
    n = new_run(rec, "write_mutants", asked=asked, proposed=len(accepted) + len(rejected), accepted=len(accepted),
                rejected=rejected, models=models, run_record=run_record)
    for a in accepted:
        e = entry_for(rec, f"AIM.{a['key']}", {
            "id": a["id"], "operator": "AIM", "line": a["line"], "description": a["description"],
            "before": " / ".join(x.strip() for x in a["before"]), "after": " / ".join(x.strip() for x in a["after"])})
        e.update(category=a["category"], reason=a["reason"], written_in=n)
    save(rec)
    return DIR / f"{unit}.md"


def add_judgements(unit, verdicts, kind, models, run_record):

    """
    Purpose: Add one run of the AI judging mutants to a module's record.
             verdicts maps a mutant's key to {id, verdict, confidence,
             reason}. Each is appended to its mutant; earlier judgements
             stay.
    """
    rec = load(unit)
    eq = sum(v["verdict"] == "equivalent" and v["confidence"] == "high" for v in verdicts.values())
    n = new_run(rec, kind, judged=len(verdicts), equivalent_high_confidence=eq, models=models,
                run_record=run_record)
    for key, v in verdicts.items():
        e = rec["mutants"].get(key)
        if e is None:
            continue
        e["judgements"].append({"run": n, "verdict": v["verdict"], "confidence": v["confidence"],
                                "reason": v["reason"]})
    save(rec)
    return DIR / f"{unit}.md"


def survivors(unit):
    """Purpose: {key: entry} of a module's present survivors the designer has not decided."""
    rec = load(unit)
    return {k: e for k, e in rec["mutants"].items() if state(e) == "survived" and decision(e) is None}


def decide(ids, what, why):

    """
    Purpose: Record the designer's decision on mutants named by id (as the
             record shows them now). Appended to each mutant and to the
             module's history. Nothing is recorded unless every id is
             found. Returns the ids not found.
    """
    known = set()
    for unit in {i.split(".")[0] for i in ids}:
        if (DIR / f"{unit}.json").exists():
            known |= {e.get("id") for e in load(unit)["mutants"].values()}
    missing = [i for i in ids if i not in known]
    if missing:
        return missing
    by_unit = {}
    for i in ids:
        by_unit.setdefault(i.split(".")[0], []).append(i)
    for unit, group in by_unit.items():
        if not (DIR / f"{unit}.json").exists():
            missing += group
            continue
        rec = load(unit)
        found = [(i, e) for i in group for e in rec["mutants"].values() if e.get("id") == i]
        missing += [i for i in group if i not in {f[0] for f in found}]
        if not found:
            continue
        n = new_run(rec, "decision", decision=what, reason=why, mutants=[i for i, _ in found])
        for _, e in found:
            e["decisions"].append({"run": n, "date": rec["runs"][-1]["date"], "decision": what, "reason": why})
        save(rec)
    return missing


def _history_row(r):
    """Purpose: one line of a record's history table."""
    where = f"{r['date']} {r['time']}", r["commit"] + (" +" if r.get("uncommitted") else "")
    if r["kind"] == "mutation":
        c = r["counts"]
        what = f"mutation run - {r['scope']}"
        result = f"{r['mutants']} mutants: " + ", ".join(f"{v} {k}" for k, v in c.items()) + f"; score {r['score']}"
    elif r["kind"] == "write_mutants":
        what = "AI wrote mutants" + (f" ({', '.join(r['models'])})" if r.get("models") else "")
        result = f"asked {r['asked']}, proposed {r['proposed']}, accepted {r['accepted']}, " \
                 f"rejected {len(r['rejected'])}" + (f"; `{r['run_record']}`" if r.get("run_record") else "")
    elif r["kind"] in ("judge", "triage"):
        what = ("AI judged survivors" if r["kind"] == "judge" else "AI triage before the tests") \
            + (f" ({', '.join(r['models'])})" if r.get("models") else "")
        result = f"{r['judged']} judged, {r['equivalent_high_confidence']} called equivalent with high confidence" \
            + (f"; `{r['run_record']}`" if r.get("run_record") else "")
    else:
        what = f"designer's decision: {r['decision']}"
        result = _cell(f"{', '.join(r['mutants'])} - {r['reason']}")
    return f"| {r['n']} | {where[0]} | {where[1]} | {what} | {result} |"


def _cell(text):
    """Purpose: text made safe for a Markdown table cell."""
    return str(text).replace("|", "\\|").replace("\n", " ")


def render(rec):

    """
    Purpose: The record written out to be read: the present state, the
             survivors with their judgements and decisions, the history of
             every step, the AI-written mutants, and every mutant with the
             outcome of every run.
    """
    c, d = counts(rec)
    ca, _ = counts(rec, lambda e: e.get("operator") == "AIM")
    cm, _ = counts(rec, lambda e: e.get("operator") != "AIM")
    out = [f"# Mutation record: {rec['module']}", "",
           f"`{rec['file']}`. Written by `tools/mutation/record.py` from `{rec['module']}.json`; every step run on "
           "this module is added, none is removed.", "", "## Now", "",
           "| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |",
           "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for name, x in (("mechanical", cm), ("AI-written", ca), ("all", c)):
        out.append(f"| {name} | {x['mutants']} | {x['killed']} | {x['lint']} | {x['covers']} | {x['timeout']} | "
                   f"{x['survived']} | {x['stillborn']} | {x['not run'] + x['error']} | {x['score']} |")
    out += ["", f"Survivors: {c['survived']} - {d['equivalent']} decided equivalent, {d['accepted']} accepted, "
                f"{d['gap']} a gap still to close, **{d['undecided']} not yet decided**. Score with the equivalent "
                f"and accepted ones taken out: {c['explained_score']}."]
    if c["retired"]:
        out.append(f"{c['retired']} earlier mutants are retired: the RTL changed and the generator no longer makes "
                   "them. Their history is kept below; they are not in these numbers.")

    surv = sorted(((e.get("line", 0), e["id"], e) for e in rec["mutants"].values() if state(e) == "survived"),
                  key=lambda x: (x[0], x[1]))
    out += ["", f"## Survivors ({len(surv)})", ""]
    for _, _, e in surv:
        out += [f"### `{e['id']}` - {e['description']}", "",
                f"- before: `{e['before']}`", f"- after: `{e['after']}`"]
        for j in e["judgements"]:
            out.append(f"- AI judgement (step {j['run']}): **{j['verdict']}**, {j['confidence']} confidence - "
                       f"{j['reason']}")
        for x in e["decisions"]:
            out.append(f"- designer's decision (step {x['run']}): **{x['decision']}** - {x['reason']}")
        if not e["decisions"]:
            out.append("- designer's decision: none yet")
        out.append("")
    if not surv:
        out += ["None.", ""]

    weak = [e for e in rec["mutants"].values() if state(e) == "covers"]
    if weak:
        out += [f"## Caught only by a lost cover ({len(weak)})", "",
                "Counted as caught, but no check failed: the behaviour is observed, not checked.", ""]
        out += [f"- `{e['id']}` - {e['description']}: `{e['before']}` -> `{e['after']}`"
                for e in sorted(weak, key=lambda e: e.get("line", 0))]
        out.append("")

    out += ["## History", "", "| Step | When | Commit | What | Result |", "|---:|---|---|---|---|"]
    out += [_history_row(r) for r in rec["runs"]]
    out += ["", "A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes."]

    written = sorted(((int(k.split(".")[1]), e) for k, e in rec["mutants"].items() if k.startswith("AIM.")),
                     key=lambda x: x[0])
    out += ["", f"## AI-written mutants ({len(written)})", ""]
    if written:
        out += ["| Key | Step | Category | The fault | Now | Killed by |", "|---:|---:|---|---|---|---|"]
        for key, e in written:
            out.append(f"| {key} | {e.get('written_in', '')} | {e.get('category', '')} | {_cell(e['description'])} | "
                       f"{state(e)} | {_cell(_killer(e))} |")
    else:
        out.append("None yet.")
    for r in rec["runs"]:
        if r["kind"] == "write_mutants" and r["rejected"]:
            out += ["", f"Rejected by the gate in step {r['n']} ({len(r['rejected'])}):", ""]
            out += [f"- {x['description']} - **{x['why']}**" for x in r["rejected"]]

    out += ["", "## Every mutant", "",
            "The outcome of every run the mutant was in, oldest first, as `step:outcome`.", "",
            "| Mutant | The edit | Outcomes | Killed by |", "|---|---|---|---|"]
    for e in sorted(rec["mutants"].values(), key=lambda e: (bool(e.get("retired")), e.get("line", 0), e["id"])):
        runs = " ".join(f"{o['run']}:{o['status']}" for o in e["outcomes"]) or "not run"
        if e.get("retired"):
            runs += f" (retired at step {e['retired']})"
        out.append(f"| `{e['id']}` | {_cell(e['description'])} | {runs} | {_cell(_killer(e))} |")
    return "\n".join(out) + "\n"


def _killer(e):
    """Purpose: what killed a mutant in its newest killed run, in a few words."""
    for o in reversed(e["outcomes"]):
        k = o.get("killed_by")
        if o["status"] == "killed" and k:
            parts = k["assertions"][:2] + k["tests"][:2]
            more = len(k["assertions"]) + len(k["tests"]) - len(parts)
            text = ", ".join(parts) + (f" +{more}" if more > 0 else "")
            if k["checks"]:
                text += (", " if text else "") + f"{k['checks']} testbench checks"
            return text or "nothing named in the log"
        if o["status"] in ("lint", "covers", "timeout", "stillborn"):
            return o.get("detail", "")
    return ""


def write_index():

    """
    Purpose: evidence/mutation/README.md: every module's present state in
             one table, rewritten from the records.
    """
    rows, tot = [], None
    for path in sorted(DIR.glob("*.json")):
        rec = json.loads(path.read_text())
        c, d = counts(rec)
        ai = sum(k.startswith("AIM.") and not e.get("retired") for k, e in rec["mutants"].items())
        steps = {k: sum(r["kind"] == k for r in rec["runs"]) for k in ("write_mutants", "mutation", "judge")}
        last = rec["runs"][-1] if rec["runs"] else {"date": "", "commit": ""}
        rows.append(f"| [`{rec['module']}`]({rec['module']}.md) | {c['mutants']} | {ai} | {c['killed']} | {c['lint']} | "
                    f"{c['covers']} | {c['timeout']} | {c['survived']} | {c['not run'] + c['error']} | {c['score']} | "
                    f"{d['undecided']} | {c['explained_score']} | {steps['write_mutants']} / {steps['mutation']} / "
                    f"{steps['judge']} | {last['date']} {last['commit']} |")
    text = ["# Mutation records", "",
            "One record per module, added to by every step run on it and never cut: the AI writing mutants "
            "(`make ai_mutants`), a mutation run (`make mutate`), the AI judging survivors (`make judge`), and the "
            "designer's decisions (`make decide`). `<module>.json` is the record; `<module>.md` is the same record "
            "written out to be read. This table is each module's present state, rewritten from the records.", "",
            "| Module | Mutants | AI-written | Killed | Lint | Covers | Timeout | Survived | Not run | Score | "
            "Survivors not decided | Score, explained survivors out | Steps: AI wrote / mutation / AI judged | "
            "Last step |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|"] + rows
    text += ["", "Score = (killed + lint + covers + timeout) / (those + survived), over each mutant's newest "
                 "outcome. The aim is no undecided survivor, not 100% - see `tools/mutation/README.md`."]
    (DIR / "README.md").write_text("\n".join(text) + "\n")


def main():

    """
    Purpose: The record's own commands: show, decide, render.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=("show", "decide", "render"))
    ap.add_argument("--modules")
    ap.add_argument("--ids")
    ap.add_argument("--as", dest="what", choices=sorted(DECISIONS))
    ap.add_argument("--why", default="")
    args = ap.parse_args()

    if args.command == "decide":
        if not args.ids or not args.what or not args.why.strip():
            sys.exit('give the mutants, the decision and the reason:  make decide IDS=<id>,<id> AS=equivalent '
                     'WHY="the reason"')
        missing = decide(args.ids.split(","), args.what, " ".join(args.why.split()))
        if missing:
            sys.exit(f"not in any record (run make mutate for the module first): {', '.join(missing)}")
        print(f"recorded: {args.what} - {args.ids}")
        return
    paths = sorted(DIR.glob("*.json"))
    if args.modules:
        paths = [p for p in paths if p.stem in args.modules.split(",")]
    if not paths:
        sys.exit("no mutation record yet - run make mutate MODULE=<module>")
    for path in paths:
        rec = json.loads(path.read_text())
        if args.command == "render":
            (DIR / f"{rec['module']}.md").write_text(render(rec))
            continue
        c, d = counts(rec)
        print(f"{rec['module']}: {c['mutants']} mutants, score {c['score']} - {c['killed']} killed, {c['lint']} lint, "
              f"{c['covers']} covers, {c['timeout']} timeout, {c['survived']} survived, "
              f"{c['not run'] + c['error']} not run")
        print(f"  survivors: {d['undecided']} not decided, {d['gap']} gap to close, {d['equivalent']} equivalent, "
              f"{d['accepted']} accepted; steps so far: {len(rec['runs'])}; record: {DIR / (rec['module'] + '.md')}")
        for e in sorted(rec["mutants"].values(), key=lambda e: e.get("line", 0)):
            if state(e) == "survived" and (decision(e) or {}).get("decision") in (None, "gap"):
                j = e["judgements"][-1] if e["judgements"] else None
                print(f"    {e['id']}  {e['description']}"
                      + (f"  [AI: {j['verdict']}, {j['confidence']}]" if j else "")
                      + ("  [gap]" if decision(e) else ""))
    if args.command == "render":
        write_index()
        print(f"rewritten: {len(paths)} records and {DIR / 'README.md'}")


if __name__ == "__main__":
    main()
