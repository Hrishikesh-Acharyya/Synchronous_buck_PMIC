#!/usr/bin/env python3
#
# Filename:         transplant_comments.py
#
# File Description: Carries the hand-written comments of an annotated sv2v split
#                   onto a fresh sv2v split of a changed source. Walks each
#                   annotated .v file and keeps its comments, whitespace and
#                   `timescale line exactly, but replaces every code token with
#                   the token in the same position of the fresh sv2v file.
#                   Refuses a file unless both have the same number of code
#                   tokens and every differing token is a number or a string,
#                   so only constant values (CLK_HZ, derived counts) and the
#                   source paths sv2v writes into elaboration messages can
#                   change; any structural difference must be merged by hand.
#
#                   Usage: transplant_comments.py <fresh_dir> <annotated_dir> <out_dir>
#                                                 [--clk-mhz N]
#
#                   Prints every changed constant, and for review by hand every
#                   comment line naming a clock in MHz - with --clk-mhz, only
#                   those naming a value other than N (the package's CLK_HZ),
#                   which is what goes stale when the clock changes. The output
#                   passes `strip_compare.py <fresh_dir> <out_dir>`.
#
# Global variables: None

import os
import re
import sys

# TOKEN: must match strip_compare.py exactly, so both scripts see the same stream
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|[A-Za-z_$][\w$]*|\d[\w\']*|\'[sS]?[bBoOdDhH][\w?]+|'
                   r'<<<|>>>|<=|>=|==|!=|===|!==|&&|\|\||<<|>>|\*\*|[^\s]')
NUMBER = re.compile(r"\d[\w']*$|'[sS]?[bBoOdDhH][\w?]+$")
MHZ = re.compile(r'(\d+(?:\.\d+)?)\s*MHz')


def code_tokens(text):
    """Code tokens of a file, comments and `timescale removed (as strip_compare)."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = n if j < 0 else j + 2
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            out.append(text[i:j + 1])
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    code = re.sub(r'`timescale[^\n]*', '', ''.join(out))
    return TOKEN.findall(code)


def transplant(ann_text, fresh_toks, rel):
    """Return (new_text, changes) or raise ValueError."""
    out, changes, k, i, n = [], [], 0, 0, len(ann_text)
    while i < n:
        if ann_text.startswith('//', i):
            j = ann_text.find('\n', i)
            j = n if j < 0 else j
            out.append(ann_text[i:j]); i = j
        elif ann_text.startswith('/*', i):
            j = ann_text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(ann_text[i:j]); i = j
        elif ann_text.startswith('`timescale', i):
            j = ann_text.find('\n', i)
            j = n if j < 0 else j
            out.append(ann_text[i:j]); i = j
        elif ann_text[i].isspace():
            out.append(ann_text[i]); i += 1
        else:
            m = TOKEN.match(ann_text, i)
            tok = m.group(0)
            if k >= len(fresh_toks):
                raise ValueError(f"{rel}: annotated file has more code tokens than sv2v output")
            new = fresh_toks[k]
            if new != tok:
                # numbers: constants such as CLK_HZ and the counts derived from it.
                # strings: sv2v writes the source path into elaboration-check
                # messages, so moving or renaming the SV folder changes them.
                same_kind = (NUMBER.match(tok) and NUMBER.match(new)) or \
                            (tok.startswith('"') and new.startswith('"'))
                if not same_kind:
                    raise ValueError(f"{rel}: token {k} '{tok}' -> '{new}' is not a constant; merge by hand")
                line = ann_text.count('\n', 0, i) + 1
                changes.append(f"{rel}:{line}: {tok} -> {new}")
            out.append(new)
            k += 1
            i = m.end()
    if k != len(fresh_toks):
        raise ValueError(f"{rel}: sv2v output has more code tokens than the annotated file")
    return ''.join(out), changes


def main():
    fresh_dir, ann_dir, out_dir = sys.argv[1:4]
    clk_mhz = None
    if '--clk-mhz' in sys.argv:
        clk_mhz = float(sys.argv[sys.argv.index('--clk-mhz') + 1])
    bad = 0
    for dirpath, _, names in os.walk(ann_dir):
        for name in sorted(names):
            if not name.endswith('.v'):
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), ann_dir)
            fresh_path = os.path.join(fresh_dir, rel)
            ann_text = open(os.path.join(ann_dir, rel), newline='').read()
            if not os.path.exists(fresh_path):
                print(f"  MISSING  {rel}: no sv2v output for it"); bad += 1; continue
            try:
                text, changes = transplant(ann_text, code_tokens(open(fresh_path).read()), rel)
            except ValueError as err:
                print(f"  REFUSED  {err}"); bad += 1; continue
            dest = os.path.join(out_dir, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            open(dest, 'w', newline='').write(text)
            print(f"  OK       {rel}  ({len(changes)} constant(s) changed)")
            for c in changes:
                print(f"             {c}")
            for no, line in enumerate(text.split('\n'), 1):
                if not ('//' in line or line.lstrip().startswith(('#', '*'))):
                    continue
                vals = [float(v) for v in MHZ.findall(line)]
                if vals and (clk_mhz is None or any(v != clk_mhz for v in vals)):
                    print(f"             review comment {rel}:{no}: {line.strip()[:90]}")
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
