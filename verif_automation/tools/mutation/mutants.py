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
#                   body, every module instance (connections and parameter
#                   overrides) and the constants declared in the body of every
#                   module, and the package's functions.
#                   Not mutated: the package's constants (design parameters,
#                   not logic), initial blocks and generate regions
#                   (elaboration-time checks), declarations and their widths,
#                   and system-task calls such as $display.
#
#                   Two mutants that mean the same thing are not both made:
#                   negating a condition that is one == / != or one negation
#                   is left to ROR / UOD, deleting an else that holds one
#                   assignment is left to SDL, and turning x_d <= x into
#                   x_d <= x_d is left to SDL too. OPERATORS.md lists them
#                   all.
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
    "ROR": "relational: boundary (< <-> <=, > <-> >=), direction (< <-> >, <= <-> >=), equality (== <-> !=)",
    "LCR": "logical connective: && <-> ||, binary & <-> |, binary ^ -> |",
    "CTD": "a term dropped from a condition: a && b -> a, and -> b (also ||, and binary & and |)",
    "CTN": "a term of a condition negated: a && b -> !a && b, and a && !b (a polarity mix-up)",
    "AOR": "arithmetic: binary + <-> -",
    "SHF": "shift direction: << <-> >>",
    "CND": "negate an if condition: if (c) -> if (!(c))",
    "CSK": "an if condition stuck: if (c) -> if (1'b1), and -> if (1'b0)",
    "UOD": "drop a unary negation: !x -> x, ~x -> x",
    "RDX": "reduction swapped: &x <-> |x (all bits set <-> any bit set)",
    "TRN": "swap the branches of a ?: - c ? a : b -> c ? b : a",
    "CST": "constant: 1'b0 <-> 1'b1, '0 <-> '1, any other integer literal +1 and -1",
    "ENM": "an enum constant replaced by the next member of its enum (an FSM state, say)",
    "DLY": "a signal swapped with its one-clock-delayed copy: x <-> x_d",
    "BSL": "wrong bit or field: a constant select moved by one - x[3] -> x[2], x[6:4] -> x[7:5]",
    "CIS": "the labels of two adjacent case items swapped",
    "CID": "one case item deleted, so its value takes the default branch (a forgotten decode)",
    "CCS": "the first two elements of a concatenation swapped: {a, b} -> {b, a}",
    "SIB": "a signal swapped with a sibling of the same type whose name differs in one part: "
           "temp_0 <-> temp_1, trip_run <-> trip_ss (a copy-paste slip)",
    "STK": "an assignment's value stuck at all-zeros, and at all-ones",
    "VNG": "an assignment's value inverted: x <= y -> x <= ~(y)",
    "EDG": "a flop clocked on the other edge: posedge clk <-> negedge clk",
    "BDL": "a whole multi-statement block emptied (the body of an if, or of a case item)",
    "SDL": "delete one procedural assignment statement",
    "EDL": "delete an else branch",
    "ICS": "wrong wire: two same-type inputs, or two same-type outputs, of one instance swapped, "
           "or the same input of two instances of one module swapped",
}

# _SWAP: operator token replacements, per operator id
_SWAP = {
    "ROR": {"<": ["<=", ">"], "<=": ["<", ">="], ">": [">=", "<"], ">=": [">", "<="], "==": ["!="], "!=": ["=="]},
    "LCR": {"&&": ["||"], "||": ["&&"], "&": ["|"], "|": ["&"], "^": ["|"]},
    "AOR": {"+": ["-"], "-": ["+"]},
    "SHF": {"<<": [">>"], ">>": ["<<"], "<<<": [">>>"], ">>>": ["<<<"]},
}
# _OPERAND_END: token texts after which an operator is binary, not unary
_OPERAND_END = {")", "]", "}"}
# _OPEN / _CLOSE: bracket tokens
_OPEN = {"(", "[", "{", "'{", "'("}
_CLOSE = {")", "]", "}"}
# _NO_SWAP_PORTS: instance inputs never swapped - every instance shares them
_NO_SWAP_PORTS = {"clk", "rst_n"}
# _TERM_STOPS: for each connective, the operators (of the same or lower
#              precedence) that end one of its operands
_TERM_STOPS = {
    "&&": {"&&", "||", "?", ":", ","},
    "||": {"||", "?", ":", ","},
    "&": {"&", "^", "|", "&&", "||", "?", ":", ","},
    "|": {"|", "&&", "||", "?", ":", ","},
}
# _DELAY_SUFFIX: how this RTL names a signal's one-clock-delayed copy
_DELAY_SUFFIX = "_d"


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


def _term_drops(src, k, first, last):

    """
    Purpose: For the binary connective at token k, the edits that drop one
             of its operands: always the right one, and the left one too when
             it is the first term of its chain (so each term of a && b && c
             is dropped exactly once). An operand runs to the next operator
             of the same or lower precedence at the same bracket depth.
    """
    toks = src.tokens
    stops = _TERM_STOPS[toks[k].text]

    def is_stop(j):
        return toks[j].text in stops and (toks[j].text in ("?", ":", ",") or _has_left_operand(toks, j))

    right, depth = last, 0
    for j in range(k + 1, last + 1):
        x = toks[j].text
        if x in _OPEN:
            depth += 1
        elif x in _CLOSE:
            if depth == 0:
                right = j - 1
                break
            depth -= 1
        elif depth == 0 and is_stop(j):
            right = j - 1
            break
    left, depth = first, 0
    for j in range(k - 1, first - 1, -1):
        x = toks[j].text
        if x in _CLOSE:
            depth += 1
        elif x in _OPEN:
            if depth == 0:
                left = j + 1
                break
            depth -= 1
        elif depth == 0 and is_stop(j):
            left = j + 1
            break
    neg = "!" if toks[k].text in ("&&", "||") else "~"

    def negated(a, b):
        """Purpose: the CTN edit for the term a..b, or None if UOD already makes it."""
        if toks[a].text in ("!", "~") and (b == a + 1 or (toks[a + 1].text == "(" and svparse.Parser(toks).close(a + 1) == b)):
            return None
        text = src.text[toks[a].start:toks[b].end]
        return "CTN", toks[a].start, toks[b].end, f"{neg}({text})", f"negate the term '{' '.join(text.split())[:40]}'"

    if right > k:
        term = " ".join(src.text[toks[k + 1].start:toks[right].end].split())
        yield "CTD", toks[k - 1].end, toks[right].end, "", f"drop the term '{term[:40]}'"
        site = negated(k + 1, right)
        if site:
            yield site
    first_of_chain = left == first or not (toks[left - 1].text in stops and toks[left - 1].text == toks[k].text)
    if left < k and first_of_chain:
        term = " ".join(src.text[toks[left].start:toks[k - 1].end].split())
        yield "CTD", toks[left].start, toks[k + 1].start, "", f"drop the term '{term[:40]}'"
        site = negated(left, k - 1)
        if site:
            yield site


def _select_sites(src, first, last):

    """
    Purpose: Constant bit and part selects between tokens first..last, each
             moved by one in both directions: x[3] -> x[4], x[2];
             x[6:4] -> x[7:5], x[5:3]. A select that lands outside the signal
             is refused by lint, so only in-range moves reach simulation.
    """
    toks = src.tokens
    for k in range(first, last + 1):
        if toks[k].text != "[" or toks[k - 1].kind != "id":
            continue
        a = toks[k + 1]
        if not re.fullmatch(r"\d+", a.text):
            continue
        if toks[k + 2].text == "]":
            n = int(a.text)
            for v in (n + 1, n - 1):
                if v >= 0:
                    yield "BSL", a.start, a.end, str(v), f"{toks[k - 1].text}[{n}] -> [{v}]"
        elif toks[k + 2].text == ":" and re.fullmatch(r"\d+", toks[k + 3].text) and toks[k + 4].text == "]":
            hi, lo = int(a.text), int(toks[k + 3].text)
            for d in (1, -1):
                if lo + d >= 0:
                    yield ("BSL", a.start, toks[k + 3].end, f"{hi + d}:{lo + d}",
                           f"{toks[k - 1].text}[{hi}:{lo}] -> [{hi + d}:{lo + d}]")


def _expr_sites(src, first, last, enums, names=frozenset(), siblings=None):

    """
    Purpose: The mutation sites inside the expression between token indices
             first..last: yields (operator id, start offset, end offset, new
             text, description). Inside [ ] only constant selects are
             touched (BSL); the width in front of a cast (8'(x)) and a
             replication count ({N{x}}) never are. names is the set of
             identifiers in the module, for DLY; siblings maps a name to its
             sibling names, for SIB.
    """
    toks = src.tokens
    siblings = siblings or {}
    yield from _select_sites(src, first, last)
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
        if t.text in _TERM_STOPS and _has_left_operand(toks, k):
            yield from _term_drops(src, k, first, last)
        if t.kind == "id" and toks[k - 1].text != "." and nxt != "(":
            other = t.text[:-len(_DELAY_SUFFIX)] if t.text.endswith(_DELAY_SUFFIX) else t.text + _DELAY_SUFFIX
            if other in names:
                yield "DLY", t.start, t.end, other, f"{t.text} -> {other}"
        for op, table in _SWAP.items():
            if t.text in table and (op in ("ROR", "SHF") or _has_left_operand(toks, k)):
                for new in table[t.text]:
                    yield op, t.start, t.end, new, f"{t.text} -> {new}"
        if t.kind == "id" and toks[k - 1].text != "." and nxt != "(":
            for other in siblings.get(t.text, ()):
                yield "SIB", t.start, t.end, other, f"{t.text} -> {other}"
        if t.text in ("!", "~") and not _has_left_operand(toks, k):
            yield "UOD", t.start, t.end, "", f"drop the '{t.text}' before {nxt}"
        if t.text in ("&", "|") and not _has_left_operand(toks, k):
            new = "|" if t.text == "&" else "&"
            yield "RDX", t.start, t.end, new, f"reduction {t.text}{nxt} -> {new}{nxt}"
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
             instance: each adjacent pair of inputs of the same type swapped,
             and each adjacent pair of connected outputs of the same type.
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
        for c in inst.connections:
            if ports.get(c[0], ("", ""))[0] == "output" and c[2] >= c[1]:
                by_type.setdefault("output " + ports[c[0]][1], []).append(c)
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


def _type_signatures(src, unit):

    """
    Purpose: For SIB: each declared name's type signature - the packed range
             as written ("[7:0]"), "1" for a single bit, the type name for an
             enum type, "param <type>" for a parameter. Two names are only
             ever swapped when their signatures are identical, so a swap
             never fails on a width.
    """
    toks = src.tokens
    sigs = {}

    def sig_of(type_text):
        m = re.search(r"\[[^\]]*\]", type_text)
        if m:
            return "".join(m.group(0).split())
        words = [w for w in type_text.split() if w not in ("wire", "logic", "reg", "bit", "signed", "unsigned", "var")]
        return words[0] if words else "1"

    for port in unit.ports:
        sigs[port.name] = sig_of(port.type)
    for param in unit.params:
        sigs[param.name] = "param " + " ".join(param.type.split())
    code = src.code[toks[unit.first].start:toks[unit.last].end]
    for m in re.finditer(r"(?m)^[ \t]*(?:logic|wire|reg|bit)\b([^;()]*);", code):
        body = m.group(1)
        rng = re.match(r"\s*(?:signed\s*)?(\[[^\]]*\])?", body)
        sig = "".join(rng.group(1).split()) if rng.group(1) else "1"
        for part in body[rng.end():].split(","):
            name = re.match(r"\s*([A-Za-z_]\w*)", part)
            if name and "[" not in part.split("=")[0][name.end():]:      # not an unpacked array
                sigs.setdefault(name.group(1), sig)
    return sigs


def _sibling_map(sigs):

    """
    Purpose: For SIB: name -> up to two sibling names. A sibling has the same
             type signature and the same name but for one underscore-
             separated part (temp_hiccup_0 / temp_hiccup_1, trip_run /
             trip_ss). Numeric neighbours come first.
    """
    by_shape = {}
    for name, sig in sigs.items():
        parts = name.split("_")
        for i in range(len(parts)):
            by_shape.setdefault((sig, len(parts), i, tuple(parts[:i] + parts[i + 1:])), []).append(name)
    out = {}
    for (sig, n, i, rest), group in by_shape.items():
        if len(group) < 2 or n < 2:
            continue
        for name in group:
            mine = name.split("_")[i]
            others = [g for g in group if g != name]

            def distance(other):
                theirs = other.split("_")[i]
                if mine.isdigit() and theirs.isdigit():
                    return (0, abs(int(mine) - int(theirs)), other)
                return (1, 0, other)
            for other in sorted(others, key=distance)[:2]:
                if other not in out.setdefault(name, []) and len(out[name]) < 2:
                    out[name].append(other)
    return out


def _value_sites(src, s, sigs):

    """
    Purpose: STK and VNG for the assignment s: its value replaced by
             all-zeros and by all-ones, and its value inverted. Not made when
             the value is a single literal (CST already changes it), and VNG
             not when the value is one negated operand (UOD already drops
             the negation). Only for a target declared as plain bits: an
             enum-typed target takes neither '0 nor an inverted value (ENM
             changes those).
    """
    toks = src.tokens
    a, b = s.value
    if b < a or (a == b and toks[a].kind == "num"):
        return
    sig = sigs.get(toks[s.target[0]].text, "")
    if sig != "1" and not sig.startswith("["):
        return
    text = src.text[toks[a].start:toks[b].end]
    short = " ".join(text.split())[:40]
    target = " ".join(src.text[toks[s.target[0]].start:toks[s.target[1]].end].split())
    yield "STK", toks[a].start, toks[b].end, "'0", f"{target} stuck at all-zeros (was '{short}')"
    yield "STK", toks[a].start, toks[b].end, "'1", f"{target} stuck at all-ones (was '{short}')"
    one_negated = toks[a].text in ("!", "~") and (b == a + 1 or (
        toks[a + 1].text == "(" and svparse.Parser(toks).close(a + 1) == b))
    if not one_negated:
        yield "VNG", toks[a].start, toks[b].end, f"~({text})", f"{target} inverted (was '{short}')"


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
        names = frozenset(t.text for t in toks[unit.first:unit.last + 1] if t.kind == "id")
        sigs = _type_signatures(src, unit) if unit.kind == "module" else {}
        sibs = _sibling_map(sigs)
        fixed = {p.name for p in unit.ports if p.direction == "input"} | {p.name for p in unit.params}
        for block in unit.blocks:
            if block.kind in ("initial", "final"):
                continue
            if unit.kind == "package" and block.kind != "function":
                continue
            if block.kind in ("always_ff", "always"):
                for k in range(block.first, block.stmt.first):
                    if toks[k].text in ("posedge", "negedge") and "clk" in toks[k + 1].text.lower():
                        other = "negedge" if toks[k].text == "posedge" else "posedge"
                        out.append((unit.name, "EDG", toks[k].start, toks[k].end, other,
                                    f"{toks[k].text} {toks[k + 1].text} -> {other} {toks[k + 1].text}"))
            driven = {(toks[s.target[0]].text, toks[s.op].text) for s in svparse.walk(block.stmt) if s.kind == "assign"}
            for s in svparse.walk(block.stmt):
                if s.kind == "other" and s.value and s.value[1] >= s.value[0]:
                    for site in _expr_sites(src, s.value[0], s.value[1], enums, names, sibs):
                        out.append((unit.name,) + site)
                elif s.kind == "assign":
                    target_text = " ".join(src.code[toks[s.target[0]].start:toks[s.target[1]].end].split())
                    for site in _expr_sites(src, s.value[0], s.value[1], enums, names, sibs):
                        if site[0] == "DLY" and site[3] == target_text and s.value[0] == s.value[1]:
                            continue        # x_d <= x_d holds the value: the same mutant as SDL
                        if site[0] == "SIB" and site[3] == target_text and s.value[0] == s.value[1]:
                            continue        # x <= x: the same mutant as SDL
                        out.append((unit.name,) + site)
                    for site in _select_sites(src, s.target[0], s.target[1]):
                        out.append((unit.name,) + site)
                    if unit.kind == "module":
                        for site in _value_sites(src, s, sigs):
                            out.append((unit.name,) + site)
                        head = toks[s.target[0]]
                        if head.kind == "id":           # the target itself swapped for a sibling
                            value_text = " ".join(src.code[toks[s.value[0]].start:toks[s.value[1]].end].split())
                            for other in sibs.get(head.text, ()):
                                # only a sibling this block already assigns the same way: the
                                # copy-paste slip between two neighbouring lines. Any other
                                # sibling is an input, a constant or a second driver - not
                                # legal code, or caught by lint at once
                                if other != value_text and other not in fixed and (other, toks[s.op].text) in driven:
                                    out.append((unit.name, "SIB", head.start, head.end, other,
                                                f"assigns to {other} instead of {head.text}"))
                    if block.kind != "assign":      # deleting a continuous assign is not legal code
                        stmt_text = src.code[toks[s.first].start:toks[s.last].end]
                        out.append((unit.name, "SDL", toks[s.first].start, toks[s.last].end, ";",
                                    f"delete '{' '.join(stmt_text.split())[:60]}'"))
                elif s.kind == "if":
                    a, b = s.cond
                    for site in _expr_sites(src, a, b, enums, names, sibs):
                        out.append((unit.name,) + site)
                    if s.then_.kind == "block" and len(s.then_.body) >= 2:
                        out.append((unit.name, "BDL", toks[s.then_.first].start, toks[s.then_.last].end, "begin end",
                                    f"empty the {len(s.then_.body)}-statement body of the if at line "
                                    f"{toks[s.first].line + 1}"))
                    was = " ".join(src.text[toks[a].start:toks[b].end].split())[:50]
                    out.append((unit.name, "CSK", toks[a].start, toks[b].end, "1'b1",
                                f"if ({was}) -> if (1'b1): always taken"))
                    then_ = s.then_
                    same_as_delete = s.else_ is None and (
                        then_.kind == "assign" or (then_.kind == "block" and (
                            len(then_.body) >= 2 or (len(then_.body) == 1 and then_.body[0].kind == "assign"))))
                    if not same_as_delete:      # with no else, never taken = the body deleted (SDL, BDL)
                        out.append((unit.name, "CSK", toks[a].start, toks[b].end, "1'b0",
                                    f"if ({was}) -> if (1'b0): never taken"))
                    if not _cnd_is_duplicate(src, a, b):
                        cond_text = src.text[toks[a].start:toks[b].end]
                        out.append((unit.name, "CND", toks[a].start, toks[b].end, f"!({cond_text})",
                                    f"if ({' '.join(cond_text.split())[:50]}) -> if (!(...))"))
                    if s.else_ is not None and not _single_assign(s.else_):
                        out.append((unit.name, "EDL", toks[s.else_tok].start, toks[s.else_.last].end, "",
                                    f"delete the else branch at line {toks[s.else_tok].line + 1}"))
                elif s.kind == "case":
                    for site in _expr_sites(src, s.cond[0], s.cond[1], enums, names, sibs):
                        out.append((unit.name,) + site)
                    for lab, body in s.items:
                        if body.kind == "block" and len(body.body) >= 2:
                            out.append((unit.name, "BDL", toks[body.first].start, toks[body.last].end, "begin end",
                                        f"empty the {len(body.body)}-statement body of the case item at line "
                                        f"{toks[body.first].line + 1}"))
                    if any(lab is None for lab, _ in s.items):     # without a default, lint: incomplete case
                        for lab, body in s.items:
                            if lab is not None:
                                label = " ".join(src.text[toks[lab[0]].start:toks[lab[1]].end].split())[:30]
                                out.append((unit.name, "CID", toks[lab[0]].start, toks[body.last].end, "",
                                            f"delete the case item '{label}': it takes the default branch"))
                    labelled = [lab for lab, _ in s.items if lab is not None]
                    for (a1, b1), (a2, b2) in zip(labelled, labelled[1:]):
                        t1 = src.text[toks[a1].start:toks[b1].end]
                        t2 = src.text[toks[a2].start:toks[b2].end]
                        between = src.text[toks[b1].end:toks[a2].start]
                        out.append((unit.name, "CIS", toks[a1].start, toks[b2].end, t2 + between + t1,
                                    f"case labels {' '.join(t1.split())[:24]} and {' '.join(t2.split())[:24]} swapped"))
        if unit.kind != "module":
            continue
        for param in unit.params:                       # constants declared in the module body
            if not param.in_header and param.span:
                for k in range(param.span[0], param.span[1] + 1):
                    nxt = toks[k + 1].text if k + 1 < len(toks) else ""
                    if toks[k].kind == "num" and nxt not in ("'(", "{", "'") and toks[k - 1].text != "[":
                        for new, what in _constant_variants(toks[k].text):
                            out.append((unit.name, "CST", toks[k].start, toks[k].end, new,
                                        f"localparam {param.name}: {what}"))
        for site in _instance_sites(src, unit, modules):
            out.append((unit.name,) + site)
        for inst in unit.instances:
            for pname, a, b in inst.overrides:
                for op, start, end, new, what in _expr_sites(src, a, b, enums):
                    out.append((unit.name, op, start, end, new, f"{inst.name} parameter {pname}: {what}"))
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
