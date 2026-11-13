#!/usr/bin/env python3
#
# Filename:         mutants.py
#
# File Description: Finds the places in the RTL where a mutation operator
#                   applies, and makes one mutant per place. Each mutant is a
#                   single small edit to one file - the kind of slip a
#                   designer makes - and is only ever written into a scratch
#                   copy of the RTL by the runner. The operators are listed in
#                   OPERATORS (and in OPERATORS.md beside this file).
#
#                   Sites come from svparse's statement tree, never from a
#                   text search, so the edit always lands on what it means to:
#                   a relational <= is never mistaken for a non-blocking
#                   assignment, and a condition is always a whole condition.
#
#                   Where mutations are made: every always / always_ff /
#                   always_comb block, every continuous assign, and every
#                   function body of every module. Not mutated: the package
#                   (its constants are design parameters, not logic), initial
#                   blocks and generate regions (elaboration-time checks),
#                   declarations, widths and bit selects, and system-task
#                   calls such as $display.
#
# Global variables: OPERATORS - the operator table

import pathlib
import re
import sys
from dataclasses import dataclass

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "common"))
import svparse  # noqa: E402

# OPERATORS: id -> what the operator does
OPERATORS = {
    "ROR": "relational boundary or equality: < <-> <=, > <-> >=, == <-> !=",
    "LCR": "logical connective: && <-> ||, binary & <-> |",
    "AOR": "arithmetic: binary + <-> -",
    "CND": "negate an if condition: if (c) -> if (!(c))",
    "CST": "constant: 1'b0 <-> 1'b1, '0 <-> '1, any other integer literal +1 and -1",
    "SDL": "delete one assignment statement",
    "EDL": "delete an else branch",
}

# _SWAP: operator token replacements, per operator id
_SWAP = {
    "ROR": {"<": ["<="], "<=": ["<"], ">": [">="], ">=": [">"], "==": ["!="], "!=": ["=="]},
    "LCR": {"&&": ["||"], "||": ["&&"], "&": ["|"], "|": ["&"]},
    "AOR": {"+": ["-"], "-": ["+"]},
}
# _OPERAND_END: token texts after which an operator is binary, not unary
_OPERAND_END = {")", "]", "}"}


@dataclass
class Mutant:

    """
    Purpose: One mutant: a stable id, where it is (file, unit, 1-based
             line), the operator, a description, and the edit - replace the
             source text between start and end offsets with new_text.
    """

    id: str
    file: str
    unit: str
    line: int
    operator: str
    description: str
    start: int
    end: int
    new_text: str

    def apply(self, text):
        """Purpose: the file's text with this mutant's edit made."""
        return text[:self.start] + self.new_text + text[self.end:]


def _is_binary(toks, k):
    """Purpose: the operator at token k has an operand on its left."""
    prev = toks[k - 1]
    return prev.kind in ("id", "num", "str") or prev.text in _OPERAND_END


def _expr_sites(toks, first, last):

    """
    Purpose: Operator and constant sites inside the expression between token
             indices first..last: yields (operator id, token index, new
             text, description). Skips everything inside [ ] (selects and
             widths), the width in front of a cast (8'(x)), and replication
             counts ({N{x}}).
    """
    depth_sq = 0
    for k in range(first, last + 1):
        t = toks[k]
        if t.text == "[":
            depth_sq += 1
        elif t.text == "]":
            depth_sq -= 1
        if depth_sq:
            continue
        for op, table in _SWAP.items():
            if t.text in table and (op == "ROR" or _is_binary(toks, k)):
                if op == "LCR" and t.text in ("&", "|") and not _is_binary(toks, k):
                    continue
                for new in table[t.text]:
                    yield op, k, new, f"{t.text} -> {new}"
        if t.kind == "num":
            nxt = toks[k + 1].text if k + 1 < len(toks) else ""
            if nxt in ("'(", "{", "'"):
                continue                # a cast width or a replication count
            for new, what in _constant_variants(t.text):
                yield "CST", k, new, what


def _constant_variants(text):

    """
    Purpose: The constant mutations of one literal, as (new text,
             description) pairs.
    """
    s = text.replace(" ", "")
    if s in ("'0", "'1"):
        other = "'1" if s == "'0" else "'0"
        return [(other, f"{s} -> {other}")]
    m = re.fullmatch(r"(\d+)?'([sS]?)([bBoOdDhH])([0-9a-fA-F_]+)", s)
    if m:
        width, signed, base, digits = m.groups()
        radix = {"b": 2, "o": 8, "d": 10, "h": 16}[base.lower()]
        value = int(digits.replace("_", ""), radix)
        prefix = f"{width or ''}'{signed}{base}"
        bits = int(width) if width else None
        out = []
        for v in (value + 1, value - 1):
            if v < 0 or (bits and v >= 2 ** bits):
                continue
            digits_new = {2: format(v, "b"), 8: format(v, "o"), 10: str(v), 16: format(v, "X")}[radix]
            out.append((prefix + digits_new, f"{s} -> {prefix + digits_new}"))
        return out
    m = re.fullmatch(r"\d[\d_]*", s)
    if m:
        value = int(s.replace("_", ""))
        return [(str(v), f"{s} -> {v}") for v in (value + 1, value - 1) if v >= 0]
    return []                           # real numbers, x / z literals: left alone


def _line_of(src, off):
    """Purpose: 1-based line of a source offset."""
    return src.text.count("\n", 0, off) + 1


def find(path, rel):

    """
    Purpose: Every mutant of one RTL file, in source order. Returns [] for a
             package. Ids are <unit>.<line>.<operator>.<n>, n counting the
             mutants of that operator on that line.
    """
    src = svparse.parse(path)
    toks = src.tokens
    out = []
    for unit in src.units:
        if unit.kind != "module":
            continue
        for block in unit.blocks:
            if block.kind in ("initial", "final"):
                continue
            for s in svparse.walk(block.stmt):
                if s.kind == "assign":
                    for op, k, new, what in _expr_sites(toks, *s.value):
                        out.append((unit.name, op, toks[k].start, toks[k].end, new, what))
                    stmt_text = src.code[toks[s.first].start:toks[s.last].end]
                    out.append((unit.name, "SDL", toks[s.first].start, toks[s.last].end, ";",
                                f"delete '{' '.join(stmt_text.split())[:60]}'"))
                elif s.kind == "if":
                    a, b = s.cond
                    for op, k, new, what in _expr_sites(toks, a, b):
                        out.append((unit.name, op, toks[k].start, toks[k].end, new, what))
                    cond_text = src.text[toks[a].start:toks[b].end]
                    out.append((unit.name, "CND", toks[a].start, toks[b].end, f"!({cond_text})",
                                f"if ({' '.join(cond_text.split())[:50]}) -> if (!(...))"))
                    if s.else_ is not None:
                        out.append((unit.name, "EDL", toks[s.else_tok].start, toks[s.else_.last].end, "",
                                    f"delete the else branch at line {toks[s.else_tok].line + 1}"))
                elif s.kind == "case":
                    for op, k, new, what in _expr_sites(toks, *s.cond):
                        out.append((unit.name, op, toks[k].start, toks[k].end, new, what))
    mutants, seen = [], {}
    for unit, op, start, end, new, what in sorted(out, key=lambda m: (m[2], m[1])):
        line = _line_of(src, start)
        key = (unit, line, op)
        seen[key] = seen.get(key, 0) + 1
        mutants.append(Mutant(f"{unit}.{line}.{op}.{seen[key]}", rel, unit, line, op, what, start, end, new))
    return mutants


def source_text(path):
    """Purpose: a file's text as the parser saw it (carriage returns removed)."""
    with open(path, "rb") as f:
        return f.read().decode("utf-8", "replace").replace("\r", "")
