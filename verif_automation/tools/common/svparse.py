#!/usr/bin/env python3
#
# Filename:         svparse.py
#
# File Description: A small SystemVerilog reader shared by the tools in
#                   verif_automation/tools. Not a full parser: it reads the
#                   subset this project's RTL uses, and says so when it meets
#                   something it does not understand.
#
#                   What it gives:
#                     - the source with comments and string contents blanked
#                       to spaces, every offset unchanged, so an edit found on
#                       the blanked text applies to the real text as is
#                     - tokens, each with its text, kind, line and offsets
#                     - for each module / package: the header block fields
#                       (Filename, File Description, Global variables), the
#                       parameters and ports with the comments that describe
#                       them, its procedural blocks and continuous assigns,
#                       and its module instances with their connections
#                     - for each procedural block: a statement tree - begin /
#                       end, if / else, case items, loops, and assignments
#                       split into target, operator and value
#
#                   Standard library only.
#
# Global variables: KEYWORDS, TYPE_WORDS, TOKEN_RE - see below

import re
from dataclasses import dataclass, field

# KEYWORDS: words that are never identifiers in the expressions this reader
#           walks
KEYWORDS = {
    "module", "endmodule", "package", "endpackage", "begin", "end", "if", "else", "case", "casez",
    "casex", "endcase", "default", "for", "foreach", "while", "repeat", "forever", "do", "always",
    "always_ff", "always_comb", "always_latch", "initial", "final", "assign", "function",
    "endfunction", "task", "endtask", "return", "unique", "unique0", "priority", "generate",
    "endgenerate", "posedge", "negedge", "or", "and", "not", "input", "output", "inout",
    "parameter", "localparam", "typedef", "enum", "struct", "packed", "import", "automatic",
    "static", "fork", "join", "join_any", "join_none", "disable", "wait",
}
# TYPE_WORDS: words that start a declaration inside a block
TYPE_WORDS = {"logic", "reg", "wire", "bit", "int", "integer", "byte", "shortint", "longint",
              "real", "realtime", "time", "string", "genvar", "var", "signed", "unsigned"}
# TOKEN_RE: one token; longest operators first
TOKEN_RE = re.compile(
    r"(?P<str>\"[^\"\n]*\")"
    r"|(?P<num>\d[\d_]*\s*'\s*[sS]?[bBoOdDhH]\s*[0-9a-fA-FxXzZ?_]+"   # sized literal 8'h0F
    r"|'[sS]?[bBoOdDhH]\s*[0-9a-fA-FxXzZ?_]+"                        # unsized based '0 'h1
    r"|'[01xXzZ](?![\w'])"                                           # '0 '1 'x 'z
    r"|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)"                         # decimal / real
    r"|(?P<sys>\$\w+)"
    r"|(?P<dir>`\w+)"
    r"|(?P<id>[A-Za-z_][\w$]*)"
    r"|(?P<op>===|!==|<<<|>>>|<->|->|\|->|\|=>|::|<=|>=|==|!=|&&|\|\||<<|>>|\*\*|\+\+|--|"
    r"\+=|-=|~&|~\||~\^|\^~|'\{|'\(|[-+*/%<>=!~&|^?:;,.()\[\]{}#@'])"
)


@dataclass
class Token:

    """
    Purpose: One token: its text, its kind (str, num, sys, dir, id, kw, op),
             its 0-based line and its start / end offsets in the source.
    """

    text: str
    kind: str
    line: int
    start: int
    end: int


@dataclass
class Comment:

    """
    Purpose: One comment: its raw text (with the // or /* */ markers), its
             first and last 0-based lines and its offsets.
    """

    text: str
    first: int
    last: int
    start: int
    end: int

    @property
    def body(self):
        """Purpose: the comment's text without the markers, lines kept."""
        t = self.text
        if t.startswith("//"):
            return t[2:].strip()
        return t[2:-2].strip("\n")


def blank(text):

    """
    Purpose: Return (code, comments): the text with every comment and the
             contents of every string replaced by spaces - newlines kept, so
             offsets and line numbers stay true - and the list of comments.
    """
    out, comments, i, n = [], [], 0, len(text)
    while i < n:
        c, nxt = text[i], text[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            comments.append((i, j))
            out.append(" " * (j - i))
            i = j
        elif c == "/" and nxt == "*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            comments.append((i, j))
            out.append("".join("\n" if ch == "\n" else " " for ch in text[i:j]))
            i = j
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"' and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(j, n - 1)
            out.append('"' + " " * (j - i - 1) + (text[j] if j > i else ""))
            i = j + 1
        else:
            out.append(c)
            i += 1
    code = "".join(out)
    line_at = _line_index(text)
    return code, [Comment(text[a:b], line_at(a), line_at(max(a, b - 1)), a, b) for a, b in comments]


def _line_index(text):

    """
    Purpose: Return a function mapping an offset to its 0-based line.
    """
    starts = [0] + [m.end() for m in re.finditer("\n", text)]

    def line_at(off):
        lo, hi = 0, len(starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if starts[mid] <= off:
                lo = mid
            else:
                hi = mid - 1
        return lo
    return line_at


def tokenize(code):

    """
    Purpose: Split blanked code into tokens. Whitespace separates; anything
             the token pattern cannot read is an error, so a construct this
             reader does not know fails loudly instead of being misread.
    """
    line_at = _line_index(code)
    toks, i, n = [], 0, len(code)
    while i < n:
        if code[i].isspace():
            i += 1
            continue
        m = TOKEN_RE.match(code, i)
        if not m:
            raise ValueError(f"unreadable text at line {line_at(i) + 1}: {code[i:i + 20]!r}")
        kind = m.lastgroup
        text = m.group(0)
        if kind == "id" and text in KEYWORDS:
            kind = "kw"
        toks.append(Token(text, kind, line_at(i), i, m.end()))
        i = m.end()
    return toks


# ==============================================================================
# Statements
# ==============================================================================

@dataclass
class Stmt:

    """
    Purpose: One statement in a procedural body. kind is one of block, if,
             case, loop, assign, decl, other, empty. first / last are token
             indices (inclusive). For if: cond = (first, last) of the
             condition inside its parentheses, then_ / else_ the branches,
             else_tok the index of the else keyword. For case: items, each
             (labels (first, last) or None for default, body). For assign:
             target (first, last), op (index of = or <=), value (first, last).
             For loop: body. For block: body (a list).
    """

    kind: str
    first: int
    last: int
    body: list = field(default_factory=list)
    cond: tuple = None
    then_: "Stmt" = None
    else_: "Stmt" = None
    else_tok: int = None
    items: list = field(default_factory=list)
    target: tuple = None
    op: int = None
    value: tuple = None


class Parser:

    """
    Purpose: Recursive-descent reader for the statements inside a procedural
             block. It knows begin / end (with labels), if / else (unique and
             priority too), case / casez / casex with their items, for /
             while / repeat / forever loops, event controls and delays, and
             simple statements. Anything else raises ValueError naming the
             line, so a mutation is never made on code it misread.
    """

    def __init__(self, toks):
        self.t = toks

    def v(self, i):
        return self.t[i].text if i < len(self.t) else None

    def close(self, i):

        """
        Purpose: Given the index of an opening bracket, return the index of
                 the matching closing one.
        """
        pairs = {"(": ")", "[": "]", "{": "}", "'{": "}", "'(": ")"}
        stack = []
        while i < len(self.t):
            x = self.v(i)
            if x in pairs:
                stack.append(pairs[x])
            elif stack and x == stack[-1]:
                stack.pop()
                if not stack:
                    return i
            i += 1
        raise ValueError(f"unbalanced bracket from line {self.t[i - 1].line + 1}")

    def stmt(self, i):

        """
        Purpose: Read the statement starting at token i; return the Stmt.
        """
        x = self.v(i)
        if x is None:
            raise ValueError("statement runs off the end of the file")
        if x in ("unique", "unique0", "priority"):
            s = self.stmt(i + 1)
            s.first = i
            return s
        if x == ";":
            return Stmt("empty", i, i)
        if x == "begin":
            j = i + 1
            if self.v(j) == ":":
                j += 2
            body = []
            while self.v(j) != "end":
                s = self.stmt(j)
                body.append(s)
                j = s.last + 1
            last = j
            if self.v(j + 1) == ":":
                last = j + 2
            return Stmt("block", i, last, body=body)
        if x == "if":
            if self.v(i + 1) != "(":
                raise ValueError(f"'if' without '(' at line {self.t[i].line + 1}")
            c = self.close(i + 1)
            then_ = self.stmt(c + 1)
            s = Stmt("if", i, then_.last, cond=(i + 2, c - 1), then_=then_)
            if self.v(then_.last + 1) == "else":
                s.else_tok = then_.last + 1
                s.else_ = self.stmt(then_.last + 2)
                s.last = s.else_.last
            return s
        if x in ("case", "casez", "casex"):
            c = self.close(i + 1)
            j = c + 1
            items = []
            while self.v(j) != "endcase":
                if self.v(j) == "default":
                    j += 1
                    if self.v(j) == ":":
                        j += 1
                    body = self.stmt(j)
                    items.append((None, body))
                else:
                    k = j
                    depth = 0
                    while not (self.v(k) == ":" and depth == 0):
                        if self.v(k) in ("(", "[", "{", "'{", "'("):
                            depth += 1
                        elif self.v(k) in (")", "]", "}"):
                            depth -= 1
                        k += 1
                    body = self.stmt(k + 1)
                    items.append(((j, k - 1), body))
                j = body.last + 1
            return Stmt("case", i, j, cond=(i + 2, c - 1), items=items)
        if x in ("for", "while", "repeat", "foreach"):
            c = self.close(i + 1)
            body = self.stmt(c + 1)
            return Stmt("loop", i, body.last, cond=(i + 2, c - 1), body=[body])
        if x == "forever":
            body = self.stmt(i + 1)
            return Stmt("loop", i, body.last, body=[body])
        if x == "@":
            j = i + 1
            j = self.close(j) + 1 if self.v(j) == "(" else j + 1
            body = self.stmt(j)
            return Stmt("other", i, body.last, body=[body])
        if x == "#":
            j = i + 1
            j = self.close(j) + 1 if self.v(j) == "(" else j + 1
            body = self.stmt(j)
            return Stmt("other", i, body.last, body=[body])
        if x in ("fork", "do", "wait", "disable"):
            raise ValueError(f"'{x}' is not read by this parser (line {self.t[i].line + 1})")
        # a simple statement: up to ';' at bracket depth 0
        j = i
        while self.v(j) != ";":
            if self.v(j) in ("(", "[", "{", "'{", "'("):
                j = self.close(j)
            if j + 1 >= len(self.t):
                raise ValueError(f"statement without ';' from line {self.t[i].line + 1}")
            j += 1
        if self.t[i].text in TYPE_WORDS or (self.t[i].kind == "id" and self.v(i + 1) == "::"):
            return Stmt("decl", i, j)
        if self.t[i].text in ("return",):
            return Stmt("other", i, j, value=(i + 1, j - 1))
        # assignment: a target (name, selects, members, or a concatenation)
        # then = or <=
        k = i
        if self.v(k) == "{":
            k = self.close(k) + 1
        elif self.t[k].kind == "id":
            k += 1
            while self.v(k) in ("[", "."):
                k = self.close(k) + 1 if self.v(k) == "[" else k + 2
        if k > i and self.v(k) in ("=", "<="):
            return Stmt("assign", i, j, target=(i, k - 1), op=k, value=(k + 1, j - 1))
        return Stmt("other", i, j)


def walk(stmt):

    """
    Purpose: Every statement in a tree, the root included, parents before
             children.
    """
    yield stmt
    if stmt.kind in ("block", "loop", "other"):
        for s in stmt.body:
            yield from walk(s)
    elif stmt.kind == "if":
        yield from walk(stmt.then_)
        if stmt.else_ is not None:
            yield from walk(stmt.else_)
    elif stmt.kind == "case":
        for _, body in stmt.items:
            yield from walk(body)


# ==============================================================================
# Modules
# ==============================================================================

@dataclass
class Port:

    """
    Purpose: One port: direction, the type and width text as written, the
             name, and the comment that describes it (trailing on its line,
             or the comment lines directly above).
    """

    direction: str
    type: str
    name: str
    comment: str


@dataclass
class Param:

    """
    Purpose: One parameter or localparam: kind, type text, name, default
             value text, and its comment (as for Port).
    """

    kind: str
    type: str
    name: str
    default: str
    comment: str
    in_header: bool = True


@dataclass
class Block:

    """
    Purpose: One procedural block or continuous assign: kind (always_ff,
             always_comb, always, initial, final, assign, function), its
             first token, and its statement tree (for assign: one assign
             Stmt).
    """

    kind: str
    first: int
    stmt: Stmt
    name: str = ""
    signature: str = ""


@dataclass
class Unit:

    """
    Purpose: One module or package: kind, name, the file it is in, the
             header fields, parameters, ports, blocks, and whether a block
             sits inside a generate region (those are elaboration-time).
    """

    kind: str
    name: str
    header: dict
    params: list
    ports: list
    blocks: list
    first: int
    last: int
    instances: list = field(default_factory=list)


@dataclass
class Instance:

    """
    Purpose: One module instantiation: the module instantiated, the instance
             name, and its named connections, each (port name, first token,
             last token of the connected expression). Unconnected ports
             (.p()) and wildcards are left out.
    """

    module: str
    name: str
    first: int
    last: int
    connections: list


@dataclass
class Source:

    """
    Purpose: One parsed file: path, raw text, blanked code, comments, tokens
             and the modules / packages in it.
    """

    path: str
    text: str
    code: str
    comments: list
    tokens: list
    units: list


def header_fields(comments):

    """
    Purpose: Read the file header block - the first comment - into its
             fields: Filename, File Description, Global variables. Each
             value is the text after the field name, continuation lines
             joined, the leading '#' and alignment removed.
    """
    if not comments:
        return {}
    body = comments[0].body.split("\n")
    fields, current = {}, None
    for line in body:
        s = line.strip()
        m = re.match(r"#?\s*(Filename|File Description|Global variables)\s*:\s*(.*)$", s)
        if m:
            current = m.group(1)
            fields[current] = [m.group(2).strip()]
        elif current:
            fields[current].append(re.sub(r"^#\s?", "", s).strip() if s else "")
    return {k: "\n".join(v).strip() for k, v in fields.items()}


def _comment_for(src_comments, line_first, line_last, raw_lines):

    """
    Purpose: The comment that describes a declaration spanning lines
             line_first..line_last: a trailing // on its last line, else the
             run of // lines (or a /* */ block) ending directly above it.
    """
    trailing = [c for c in src_comments if c.first == line_last and c.text.startswith("//")
                and raw_lines[c.first][:raw_lines[c.first].find("//")].strip()]
    if trailing:
        return trailing[-1].body
    above, k = [], line_first - 1
    by_last = {c.last: c for c in src_comments}
    while k >= 0 and k in by_last and not raw_lines[k][:raw_lines[k].find(by_last[k].text.split("\n")[-1])].strip():
        c = by_last[k]
        if re.fullmatch(r"[=\-#*/ ]{4,}", c.body.strip() or "x"):
            break                       # a section banner: it heads a section, not this declaration
        above.insert(0, c.body)
        if not c.text.startswith("//"):
            break
        k = c.first - 1
    return "\n".join(above)


def parse(path, text=None):

    """
    Purpose: Read one .sv / .v file into a Source.
    """
    if text is None:
        with open(path, "rb") as f:
            text = f.read().decode("utf-8", "replace").replace("\r", "")
    code, comments = blank(text)
    toks = tokenize(code)
    raw_lines = text.split("\n")
    units = []
    i = 0
    while i < len(toks):
        if toks[i].text in ("module", "package"):
            units.append(_read_unit(toks, i, comments, raw_lines, code))
            i = units[-1].last + 1
        else:
            i += 1
    return Source(path, text, code, comments, toks, units)


def _read_unit(toks, i, comments, raw_lines, code):

    """
    Purpose: Read the module or package starting at token i: header fields,
             parameters, ports and blocks.
    """
    kind = toks[i].text
    name = toks[i + 1].text
    end_kw = "endmodule" if kind == "module" else "endpackage"
    last = next(k for k in range(i, len(toks)) if toks[k].text == end_kw)
    p = Parser(toks)
    params, ports, blocks, instances = [], [], [], []
    j = i + 2
    # a package import between the name and the lists
    while toks[j].text == "import":
        while toks[j].text != ";":
            j += 1
        j += 1
    # #( parameter list )
    if j < last and toks[j].text == "#":
        c = p.close(j + 1)
        params += _read_decls(toks, j + 2, c - 1, comments, raw_lines, code, "param")
        j = c + 1
    # ( port list );
    if toks[j].text == "(":
        c = p.close(j)
        ports += _read_decls(toks, j + 1, c - 1, comments, raw_lines, code, "port")
        j = c + 1
    if toks[j].text == ";":
        j += 1
    body_first = j
    # module items
    generate_depth = 0
    while j < last:
        t = toks[j].text
        if t == "generate":
            generate_depth += 1
            j += 1
            continue
        if t == "endgenerate":
            generate_depth -= 1
            j += 1
            continue
        if t in ("parameter", "localparam"):
            k = j
            while toks[k].text != ";":
                k = p.close(k) if toks[k].text in ("(", "[", "{") else k
                k += 1
            body_params = _read_decls(toks, j, k - 1, comments, raw_lines, code, "param")
            for bp in body_params:
                bp.in_header = kind == "package"
            params += body_params
            j = k + 1
            continue
        if t in ("always", "always_ff", "always_comb", "always_latch", "initial", "final") \
                and generate_depth == 0:
            k = j + 1
            while toks[k].text in ("@", "#"):
                k = p.close(k + 1) + 1 if toks[k + 1].text == "(" else k + 2
            s = p.stmt(k)
            blocks.append(Block(t, j, s))
            j = s.last + 1
            continue
        if t == "assign" and generate_depth == 0:
            k = j + 1
            while toks[k].text != ";":
                k = p.close(k) if toks[k].text in ("(", "[", "{") else k
                k += 1
            s = p.stmt(j + 1)
            blocks.append(Block("assign", j, s))
            j = s.last + 1
            continue
        if t == "function" and generate_depth == 0:
            k = j
            while toks[k].text != ";":
                k = p.close(k) if toks[k].text in ("(", "[", "{") else k
                k += 1
            name_tok = toks[k - 1] if toks[k - 1].text != ")" else \
                toks[next(m for m in range(k - 1, j, -1) if toks[m].text == "(") - 1]
            body, m = [], k + 1
            while toks[m].text != "endfunction":
                s = p.stmt(m)
                body.append(s)
                m = s.last + 1
            blocks.append(Block("function", j, Stmt("block", k + 1, m - 1, body=body), name_tok.text,
                                _span_text(code, toks[j], toks[k - 1]) if k > j else ""))
            j = m + 1
            continue
        inst = _read_instance(toks, j, p) if kind == "module" else None
        if inst is not None:
            instances.append(inst)
            j = inst.last + 1
            continue
        j += 1
    return Unit(kind, name, header_fields(comments), params, ports, blocks, i, last, instances)


def _read_instance(toks, j, p):

    """
    Purpose: If a module instantiation starts at token j - a module name, an
             optional #( ) parameter list, an instance name, then a
             parenthesised connection list - return it; otherwise None. Only
             tried where a module item can start, so a call inside an
             expression is never taken for one.
    """
    if toks[j].kind != "id" or toks[j].text in TYPE_WORDS:
        return None
    prev = toks[j - 1].text
    after_label = toks[j - 1].kind == "id" and toks[j - 2].text == ":"
    if prev not in (";", "end", "begin", "generate", "endgenerate", "endfunction", "endtask") and not after_label:
        return None
    k = j + 1
    if toks[k].text == "#":
        if toks[k + 1].text != "(":
            return None
        k = p.close(k + 1) + 1
    if not (toks[k].kind == "id" and toks[k + 1].text == "(" and toks[k + 2].text in (".", ")")):
        return None
    c = p.close(k + 1)
    conns, m = [], k + 2
    while m < c:
        if toks[m].text == "." and toks[m + 1].kind == "id" and toks[m + 2].text == "(":
            e = p.close(m + 2)
            if e - 1 >= m + 3:
                conns.append((toks[m + 1].text, m + 3, e - 1))
            m = e + 1
        else:
            m += 1
    last = c + 1 if toks[c + 1].text == ";" else c
    return Instance(toks[j].text, toks[k].text, j, last, conns)


def _read_decls(toks, first, last, comments, raw_lines, code, what):

    """
    Purpose: Read a comma-separated list of parameter or port declarations
             between token indices first..last. A declaration with no comment
             of its own takes its group's: the last comment written above a
             declaration in the same run (a blank line ends the run).
    """
    out, j = [], first
    current_dir, current_type, current_kind = "", "", "parameter"
    group, prev_last = "", None
    while j <= last:
        # one declaration: up to ',' or ';' at depth 0, or the end
        k, depth = j, 0
        while k <= last and not (toks[k].text in (",", ";") and depth == 0):
            if toks[k].text in ("(", "[", "{", "'{", "'("):
                depth += 1
            elif toks[k].text in (")", "]", "}"):
                depth -= 1
            k += 1
        seg = toks[j:k]
        if seg:
            words = [t.text for t in seg]
            line_first, line_last = seg[0].line, seg[-1].line
            if prev_last is not None and any(not raw_lines[n].strip() for n in range(prev_last + 1, line_first)):
                group = ""
            prev_last = line_last
            own = _comment_for(comments, line_first, line_last, raw_lines)
            above = _comment_for(comments, line_first, line_first, raw_lines) if line_first != line_last else own
            decl_name = next((t.text for t in reversed(seg) if t.kind == "id"), "")
            names_itself = re.match(rf"\s*{re.escape(decl_name)}\b", own or "")
            if own and own == above and not _has_trailing(comments, line_last, raw_lines):
                group = "" if names_itself else own
            if what == "port":
                if words[0] in ("input", "output", "inout"):
                    current_dir = words[0]
                    words = words[1:]
                    seg = seg[1:]
                name = seg[-1].text
                typ = _span_text(code, seg[0], seg[-2]) if len(seg) > 1 else current_type
                current_type = typ
                out.append(Port(current_dir, typ, name, own or group))
            else:
                if words[0] in ("parameter", "localparam"):
                    current_kind = words[0]
                    seg = seg[1:]
                eq = next((n for n, t in enumerate(seg) if t.text == "="), None)
                if eq is None:
                    j = k + 1
                    continue
                name = seg[eq - 1].text
                typ = _span_text(code, seg[0], seg[eq - 2]) if eq >= 2 else ""
                default = _span_text(code, seg[eq + 1], seg[-1])
                out.append(Param(current_kind, typ, name, default, own or group))
        j = k + 1
    return out


def _span_text(code, a, b):
    """Purpose: the source text from token a to token b, whitespace runs as one space."""
    return re.sub(r"\s+", " ", code[a.start:b.end]).strip()


def _has_trailing(comments, line, raw_lines):
    """Purpose: line carries code followed by a // comment."""
    return any(c.first == line and c.text.startswith("//") and raw_lines[line][:raw_lines[line].find("//")].strip()
               for c in comments)
