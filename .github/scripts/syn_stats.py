#!/usr/bin/env python3
#
# Filename:         syn_stats.py
#
# File Description: Reads two yosys `stat` logs (PR head and base) and prints
#                   a markdown comparison of total cells, flops, latches and
#                   the per-type breakdown. Parses both the older yosys
#                   layout ("$_AND_   1329") and the newer one
#                   ("1329   $_AND_"), since the runner's packaged yosys and
#                   the local oss-cad-suite build print differently.
#
#                   Only the LAST statistics block for pmic_top is read: the
#                   synth pass prints one of its own before the final stat.
#                   $scopeinfo is dropped - it is a debug annotation, not
#                   hardware, and newer yosys counts it as a cell.
#
# Global variables: None

import argparse
import re
import sys
from pathlib import Path

# NEW_CELL / OLD_CELL: one cell-type line in each yosys layout.
NEW_CELL = re.compile(r"^\s*(\d+)\s+(\$\S+)\s*$")
OLD_CELL = re.compile(r"^\s*(\$\S+)\s+(\d+)\s*$")

# FLOP_PREFIXES / LATCH_PREFIXES: yosys internal cell names for edge-triggered
# storage and for level-sensitive storage after techmap.
FLOP_PREFIXES = ("$_DFF", "$_SDFF", "$_ALDFF")
LATCH_PREFIXES = ("$_DLATCH",)


def parse(path):
    """Return {cell_type: count} from the last pmic_top block, or None."""
    p = Path(path)
    if not p.is_file():
        return None
    lines = p.read_text(errors="replace").splitlines()
    starts = [i for i, l in enumerate(lines) if l.strip() == "=== pmic_top ==="]
    if not starts:
        return None
    cells = {}
    for line in lines[starts[-1] + 1:]:
        if line.startswith(("===", "Warnings:", "End of script")):
            break
        m = NEW_CELL.match(line)
        if m:
            cells[m.group(2)] = int(m.group(1))
            continue
        m = OLD_CELL.match(line)
        if m:
            cells[m.group(1)] = int(m.group(2))
    cells.pop("$scopeinfo", None)
    return cells or None


def summary(cells):
    """Total, flop and latch counts for one parsed block."""
    return {
        "cells": sum(cells.values()),
        "flops": sum(n for t, n in cells.items() if t.startswith(FLOP_PREFIXES)),
        "latches": sum(n for t, n in cells.items() if t.startswith(LATCH_PREFIXES)),
    }


def delta(base, head):
    """Signed change with a percentage, or a dash when there is no base."""
    if base is None:
        return "-"
    d = head - base
    if d == 0:
        return "0"
    pct = f" ({d / base * 100:+.1f}%)" if base else ""
    return f"{d:+d}{pct}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--head", required=True)
    ap.add_argument("--base", required=True)
    args = ap.parse_args()

    head = parse(args.head)
    base = parse(args.base)
    if head is None:
        print("### Synthesis trend\n\nCould not read the head synthesis log.")
        return 1

    hs = summary(head)
    bs = summary(base) if base else None

    out = ["### Synthesis trend (yosys, generic cells, pmic_top flattened)", ""]
    if base is None:
        out += ["_Base did not synthesise - showing the head alone._", ""]

    out += ["| | base | head | change |", "|---|---:|---:|---:|"]
    for key in ("cells", "flops", "latches"):
        b = bs[key] if bs else None
        out.append(f"| {key} | {'-' if b is None else b} | {hs[key]} | {delta(b, hs[key])} |")
    out.append("")

    # Latches are never intended in this design; one appearing is a defect.
    if hs["latches"]:
        out += [f"**Warning:** the head infers {hs['latches']} latch cell(s). "
                "No latch is intended anywhere in this design.", ""]

    # Per-type breakdown, only for types that moved, so the comment stays short.
    if base:
        moved = sorted(t for t in set(head) | set(base) if head.get(t, 0) != base.get(t, 0))
        if moved:
            out += ["<details><summary>Cell types that changed</summary>", "",
                    "| type | base | head | change |", "|---|---:|---:|---:|"]
            for t in moved:
                b, h = base.get(t, 0), head.get(t, 0)
                out.append(f"| `{t}` | {b} | {h} | {h - b:+d} |")
            out += ["", "</details>", ""]
        else:
            out += ["No cell type changed count.", ""]

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())