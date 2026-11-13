#!/usr/bin/env python3
#
# Filename:         extract_contract.py
#
# File Description: Extracts each RTL module's contract - what it promises at
#                   its boundary - into a machine-readable form, for the tools
#                   and agent tasks that must work from the contract and not
#                   from the implementation.
#
#                   The contract of a module is:
#                     - its file header (File Description, Global variables)
#                     - its parameters, with type, default and description
#                     - its ports, with direction, type, width and description
#                   The contract of the package is its constants and the
#                   signatures and Purpose text of its functions.
#                   Nothing from a module's body is included: no logic, no
#                   internal signals, no Purpose blocks of its always blocks.
#                   That is the point - a checker or model written from this
#                   cannot copy the design's own mistakes.
#
#                   Gaps are listed too: a port or parameter with no
#                   description is part of the contract nobody wrote down.
#
#                   Usage: extract_contract.py [--out DIR] [files or folders...]
#                     default input  rtl-systemverilog/ (tracked .sv files)
#                     default output verif_automation/build/contract/
#                   Writes <unit>.json and <unit>.md per module / package, and
#                   index.md listing every unit and its gaps.
#
# Global variables: REPO - the repository root

import argparse
import datetime
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "common"))
import svparse  # noqa: E402

# REPO: the repository root, from git (or two levels above this tool)
REPO = pathlib.Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True,
                                   cwd=pathlib.Path(__file__).parent).stdout.strip()
                    or pathlib.Path(__file__).resolve().parents[3])


def sources(paths):

    """
    Purpose: The .sv files to read: tracked files under the given paths
             (default rtl-systemverilog/).
    """
    roots = paths or ["rtl-systemverilog"]
    out = subprocess.run(["git", "ls-files", "--", *roots], cwd=REPO, capture_output=True, text=True).stdout.split()
    return sorted(f for f in out if f.endswith(".sv"))


def function_purpose(src, block):

    """
    Purpose: The Purpose text written inside a function, directly after its
             declaration - the package's functions carry their description
             there.
    """
    decl_line = src.tokens[block.stmt.first - 1].line if block.stmt.first > 0 else 0
    first_stmt_line = src.tokens[block.stmt.first].line if block.stmt.body else decl_line + 1
    for c in src.comments:
        if decl_line < c.first <= first_stmt_line and "Purpose" in c.text:
            body = c.body.split("\n")
            body = [b.strip() for b in body if b.strip() not in ("Purpose:", "---")]
            return "\n".join(b for b in body if b)
    return ""


def contract(src, unit, rel):

    """
    Purpose: Build the contract record for one module or package.
    """
    rec = {
        "unit": unit.name,
        "kind": unit.kind,
        "file": rel,
        "description": unit.header.get("File Description", ""),
        "global_variables": unit.header.get("Global variables", ""),
        "parameters": [
            {"name": p.name, "kind": p.kind, "type": p.type, "default": p.default, "description": p.comment}
            for p in unit.params if p.in_header
        ],
        "ports": [
            {"name": p.name, "direction": p.direction, "type": p.type, "description": p.comment}
            for p in unit.ports
        ],
    }
    if unit.kind == "package":
        rec["functions"] = [
            {"name": b.name, "signature": b.signature, "description": function_purpose(src, b)}
            for b in unit.blocks if b.kind == "function"
        ]
    rec["gaps"] = [f"port {p['name']}: no description" for p in rec["ports"]
                   if not p["description"] and p["name"] not in ("clk", "rst_n")] + \
                  [f"parameter {p['name']}: no description" for p in rec["parameters"] if not p["description"]]
    return rec


def as_markdown(rec):

    """
    Purpose: The same record as a readable page.
    """
    def cell(s):
        return (s or "-").replace("|", "\\|").replace("\n", " ")
    out = [f"# {rec['unit']} ({rec['kind']})", "", f"Source: `{rec['file']}`", "", "## Description", "",
           rec["description"] or "(none)", ""]
    if rec["global_variables"] and rec["global_variables"] != "None":
        out += ["## Global variables", "", rec["global_variables"], ""]
    if rec["parameters"]:
        out += ["## Parameters", "", "| Name | Kind | Type | Default | Description |", "|---|---|---|---|---|"]
        out += [f"| `{p['name']}` | {p['kind']} | `{cell(p['type'])}` | `{cell(p['default'])}` | {cell(p['description'])} |"
                for p in rec["parameters"]]
        out.append("")
    if rec["ports"]:
        out += ["## Ports", "", "| Name | Direction | Type | Description |", "|---|---|---|---|"]
        out += [f"| `{p['name']}` | {p['direction']} | `{cell(p['type'])}` | {cell(p['description'])} |"
                for p in rec["ports"]]
        out.append("")
    for f in rec.get("functions", []):
        out += [f"## Function `{f['name']}`", "", f"`{f['signature']}`", "", f["description"] or "(no description)", ""]
    if rec["gaps"]:
        out += ["## Gaps", ""] + [f"- {g}" for g in rec["gaps"]] + [""]
    return "\n".join(out)


def main():

    """
    Purpose: Read the sources, write one JSON and one Markdown file per unit,
             and an index.
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--out", default=str(REPO / "verif_automation" / "build" / "contract"))
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                            text=True).stdout.strip() or "unknown"
    stamp = {"date": datetime.date.today().isoformat(), "commit": commit}
    index = ["# Contracts", "", f"Extracted {stamp['date']} at commit {commit} by `extract_contract.py`.", "",
             "| Unit | Kind | Parameters | Ports | Gaps |", "|---|---|---:|---:|---:|"]
    total_gaps = 0
    for rel in sources(args.paths):
        src = svparse.parse(str(REPO / rel))
        for unit in src.units:
            rec = contract(src, unit, rel)
            rec["extracted"] = stamp
            (out / f"{unit.name}.json").write_text(json.dumps(rec, indent=2) + "\n")
            (out / f"{unit.name}.md").write_text(as_markdown(rec) + "\n")
            index.append(f"| [{unit.name}]({unit.name}.md) | {unit.kind} | {len(rec['parameters'])} | "
                         f"{len(rec['ports'])} | {len(rec['gaps'])} |")
            total_gaps += len(rec["gaps"])
            print(f"  {unit.name:18s} {unit.kind:8s} {len(rec['parameters']):3d} parameters "
                  f"{len(rec['ports']):3d} ports {len(rec['gaps']):3d} gaps")
    (out / "index.md").write_text("\n".join(index) + "\n")
    print(f"contracts written to {out} ({total_gaps} gaps)")


if __name__ == "__main__":
    main()
