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
#                   always_comb block, every continuous assign, every function
#                   body and every module instance of every module. Not
#                   mutated: the package (its constants are design parameters,
#                   not logic), initial blocks and generate regions
#                   (elaboration-time checks), declarations, widths and bit
#                   selects, and system-task calls such as $display.
#
#                   Two mutants that mean the same thing are not both made:
#                   negating a condition that is one == / != or one negation
#                   is left to ROR / UOD, and deleting an else that holds one
#                   assignment is left to SDL.
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
    "SHF": "shift direction: << <-> >>",
    "CND": "negate an if condition: if (c) -> if (!(c))",
    "UOD": "drop a unary negation: !x -> x, ~x -> x",
    "TRN": "swap the branches of a ?: - c ? a : b -> c ? b : a",
    "CST": "constant: 1'b0 <-> 1'b1, '0 <-> '1, any other integer literal +1 and -1",
    "ENM": "an enum constant replaced by the next member of its enum (an FSM state, say)",
    "CCS": "the first two elements of a concatenation swapped: {a, b} -> {b, a}",
    "SDL": "delete one procedural assignment statement",
    "EDL": "delete an else branch",
    "ICS": "wrong wire: two same-type inputs of one instance swapped, or the same input of two "
           "instances of one module swapped",
}

# _SWAP: operator token replacements, per operator id
_SWAP = {
    "ROR": {"<": "<=", "<=": "<", ">": ">=", ">=": ">", "==": "!=", "!=": "=="},
    "LCR": {"&&": "||", "||": "&&", "&": "|", "|": "&"},
    "AOR": {"+": "-", "-": "+"},
    "SHF": {"<<": ">>", ">>": "<<", "<<<": ">>>", ">>>": "<<<"},
}
# _OPERAND_END: token texts after which an operator is binary, not unary
_OPERAND_END = {")", "]", "}"}
# _OPEN / _CLOSE: bracket tokens
_OPEN = {"(", "[", "{", "'{", "'("}
_CLOSE = {")", "]", "}"}
# _NO_SWAP_PORTS: instance inputs never swapped - every instance shares them
_NO_SWAP_PORTS = {"clk", "rst_n"}


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


def _has_left_operand(toks, k):
    """Purpose: the token at k has an operand on its left (so it is binary)."""
    prev = toks[k - 1]
    return prev.kind in ("id", "num", "str") or prev.text in _OPERAND_END


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
    if re.fullmatch(r"\d[\d_]*", s):
        value = int(s.replace("_", ""))
        return [(str(v), f"{s} -> {v}") for v in (value + 1, value - 1) if v >= 0]
    return []                           # real numbers, x / z literals: left alone


def _expr_sites(src, first, last, enums):

    """
    Purpose: The mutation sites inside the expression between token indices
             first..last: yields (operator id, start offset, end offset, new
             text, description). Nothing inside [ ] is touched (selects and
             widths), nor the width in front of a cast (8'(x)), nor a
             replication count ({N{x}}).
    """
    toks = src.tokens
    depth_sq = 0
    for k in range(first, last + 1):
        t = toks[k]
        if t.text == "[":
            depth_sq += 1
        elif t.text == "]":
            depth_sq -= 1
        if depth_sq:
            continue
        nxt = toks[k + 1].text if k + 1 < len(toks) else ""
        for op, table in _SWAP.items():
            if t.text in table and (op in ("ROR", "SHF") or _has_left_operand(toks, k)):
                yield op, t.start, t.end, table[t.text], f"{t.text} -> {table[t.text]}"
        if t.text in ("!", "~") and not _has_left_operand(toks, k):
            yield "UOD", t.start, t.end, "", f"drop the '{t.text}' before {nxt}"
        if t.kind == "num" and nxt not in ("'(", "{", "'"):
            for new, what in _constant_variants(t.text):
                yield "CST", t.start, t.end, new, what
        if t.kind == "id" and t.text in enums and toks[k - 1].text != ".":
            members = enums[t.text]
            new = members[(members.index(t.text) + 1) % len(members)]
            yield "ENM", t.start, t.end, new, f"{t.text} -> {new}"
        if t.text == "?":
            site = _ternary(src, k, last)
            if site:
                yield ("TRN",) + site
        if t.text == "{" and toks[k - 1].kind != "num" and toks[k - 1].text != "{":
            site = _concat(src, k)
            if site:
                yield ("CCS",) + site


def _ternary(src, q, last):

    """
    Purpose: For the ? at token q, the edit that swaps its two branches, or
             None. The else branch runs to the end of the expression, or to
             the bracket or comma that ends the level the ? sits at.
    """
    toks = src.tokens
    depth, nested, colon = 0, 0, None
    for k in range(q + 1, last + 1):
        x = toks[k].text
        if x in _OPEN:
            depth += 1
        elif x in _CLOSE:
            if depth == 0:
                return None
            depth -= 1
        elif depth == 0 and x == "?":
            nested += 1
        elif depth == 0 and x == ":":
            if nested == 0:
                colon = k
                break
            nested -= 1
    if colon is None or colon == q + 1:
        return None
    end, depth = last, 0
    for k in range(colon + 1, last + 1):
        x = toks[k].text
        if x in _OPEN:
            depth += 1
        elif x in _CLOSE:
            if depth == 0:
                end = k - 1
                break
            depth -= 1
        elif depth == 0 and x == ",":
            end = k - 1
            break
    if end <= colon:
        return None
    a = src.text[toks[q + 1].start:toks[colon - 1].end]
    b = src.text[toks[colon + 1].start:toks[end].end]
    if " ".join(a.split()) == " ".join(b.split()):
        return None
    between = src.text[toks[colon - 1].end:toks[colon + 1].start]
    return toks[q + 1].start, toks[end].end, b + between + a, "swap the branches of ?:"


def _concat(src, k):

    """
    Purpose: For the { at token k, the edit that swaps the first two
             elements of the concatenation, or None (fewer than two elements,
             or a replication).
    """
    toks = src.tokens
    depth, commas, close = 0, [], None
    for j in range(k + 1, len(toks)):
        x = toks[j].text
        if x in _OPEN:
            depth += 1
        elif x in _CLOSE:
            if depth == 0:
                close = j
                break
            depth -= 1
        elif depth == 0 and x == ",":
            commas.append(j)
    if close is None or not commas:
        return None
    first_end = commas[0] - 1
    second_end = (commas[1] if len(commas) > 1 else close) - 1
    if toks[k + 1].kind == "num" and toks[k + 2].text == "{" and first_end == k + 1:
        return None
    a = src.text[toks[k + 1].start:toks[first_end].end]
    b = src.text[toks[commas[0] + 1].start:toks[second_end].end]
    if " ".join(a.split()) == " ".join(b.split()):
        return None
    between = src.text[toks[first_end].end:toks[commas[0] + 1].start]
    return (toks[k + 1].start, toks[second_end].end, b + between + a,
            f"swap '{a.strip()[:24]}' and '{b.strip()[:24]}'")


def _cnd_is_duplicate(src, a, b):

    """
    Purpose: Negating the condition between tokens a..b would repeat another
             mutant: the condition is a single == / != comparison (ROR makes
             the same change) or a single negated operand (UOD does).
    """
    toks = src.tokens
    while toks[a].text == "(" and svparse.Parser(toks).close(a) == b:
        a, b = a + 1, b - 1
    depth, top = 0, []
    for k in range(a, b + 1):
        x = toks[k].text
        if x in _OPEN:
            depth += 1
        elif x in _CLOSE:
            depth -= 1
        elif depth == 0 and toks[k].kind == "op" and x not in (".", "::", "'"):
            top.append((k, x))
    if len(top) == 1 and top[0][1] in ("==", "!="):
        return True
    return len(top) == 1 and top[0][0] == a and top[0][1] in ("!", "~")


def _single_assign(stmt):
    """Purpose: the statement is one assignment, bare or alone in a begin / end."""
    if stmt.kind == "assign":
        return True
    return stmt.kind == "block" and len(stmt.body) == 1 and stmt.body[0].kind == "assign"


def _instance_sites(src, unit, modules):

    """
    Purpose: Wrong-wire mutants of a module's instances. Within one
             instance: each adjacent pair of inputs of the same type swapped.
             Across instances of one module: the same input of each
             consecutive pair of instances swapped. clk and rst_n are left
             alone, and so is any pair already wired to the same thing.
    """
    toks = src.tokens

    def text(conn):
        return src.text[toks[conn[1]].start:toks[conn[2]].end]

    def swap(a, b, what):
        ta, tb = text(a), text(b)
        if " ".join(ta.split()) == " ".join(tb.split()):
            return None
        between = src.text[toks[a[2]].end:toks[b[1]].start]
        return "ICS", toks[a[1]].start, toks[b[2]].end, tb + between + ta, what

    by_module = {}
    for inst in unit.instances:
        ports = modules.get(inst.module, {})
        inputs = [c for c in inst.connections if ports.get(c[0], ("", ""))[0] == "input"
                  and c[0] not in _NO_SWAP_PORTS]
        by_type = {}
        for c in inputs:
            by_type.setdefault(ports[c[0]][1], []).append(c)
        for group in by_type.values():
            for a, b in zip(group, group[1:]):
                site = swap(a, b, f"{inst.name}: .{a[0]} and .{b[0]} swapped")
                if site:
                    yield site
        by_module.setdefault(inst.module, []).append((inst, {c[0]: c for c in inputs}))
    for module, insts in by_module.items():
        for (i1, c1), (i2, c2) in zip(insts, insts[1:]):
            for port in c1:
                if port in c2:
                    site = swap(c1[port], c2[port], f".{port} of {i1.name} and {i2.name} swapped")
                    if site:
                        yield site


def design_info(rtl_root):

    """
    Purpose: What the instance and enum operators need from the whole
             design: for each module, its ports as {name: (direction, type)},
             and for each enum member, the member list of its enum.
    """
    modules, enums = {}, {}
    for path in sorted(pathlib.Path(rtl_root).rglob("*.sv")):
        src = svparse.parse(str(path))
        for unit in src.units:
            if unit.kind == "module":
                modules[unit.name] = {p.name: (p.direction, " ".join(p.type.split())) for p in unit.ports}
        for m in re.finditer(r"typedef\s+enum\b[^{;]*\{([^}]*)\}", src.code):
            members = [re.match(r"\s*(\w+)", part).group(1) for part in m.group(1).split(",") if part.strip()]
            for name in members:
                enums[name] = members
    return modules, enums


def find(path, rel, info=None):

    """
    Purpose: Every mutant of one RTL file, in source order. Returns [] for a
             package. Ids are <unit>.<line>.<operator>.<n>, n counting the
             mutants of that operator on that line. info is design_info()
             of the RTL tree; it is worked out from the file's own tree when
             not given.
    """
    if info is None:
        root = next((p for p in pathlib.Path(path).resolve().parents if p.name == "rtl-systemverilog"),
                    pathlib.Path(path).resolve().parent)
        info = design_info(root)
    modules, enums = info
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
                    for site in _expr_sites(src, s.value[0], s.value[1], enums):
                        out.append((unit.name,) + site)
                    if block.kind != "assign":      # deleting a continuous assign is not legal code
                        stmt_text = src.code[toks[s.first].start:toks[s.last].end]
                        out.append((unit.name, "SDL", toks[s.first].start, toks[s.last].end, ";",
                                    f"delete '{' '.join(stmt_text.split())[:60]}'"))
                elif s.kind == "if":
                    a, b = s.cond
                    for site in _expr_sites(src, a, b, enums):
                        out.append((unit.name,) + site)
                    if not _cnd_is_duplicate(src, a, b):
                        cond_text = src.text[toks[a].start:toks[b].end]
                        out.append((unit.name, "CND", toks[a].start, toks[b].end, f"!({cond_text})",
                                    f"if ({' '.join(cond_text.split())[:50]}) -> if (!(...))"))
                    if s.else_ is not None and not _single_assign(s.else_):
                        out.append((unit.name, "EDL", toks[s.else_tok].start, toks[s.else_.last].end, "",
                                    f"delete the else branch at line {toks[s.else_tok].line + 1}"))
                elif s.kind == "case":
                    for site in _expr_sites(src, s.cond[0], s.cond[1], enums):
                        out.append((unit.name,) + site)
        for site in _instance_sites(src, unit, modules):
            out.append((unit.name,) + site)
    mutants, seen = [], {}
    for unit, op, start, end, new, what in sorted(out, key=lambda m: (m[2], m[1], m[4])):
        line = src.text.count("\n", 0, start) + 1
        key = (unit, line, op)
        seen[key] = seen.get(key, 0) + 1
        mutants.append(Mutant(f"{unit}.{line}.{op}.{seen[key]}", rel, unit, line, op, what, start, end, new))
    return mutants


def source_text(path):
    """Purpose: a file's text as the parser saw it (carriage returns removed)."""
    with open(path, "rb") as f:
        return f.read().decode("utf-8", "replace").replace("\r", "")
