#!/usr/bin/env python3
#
# Filename:         strip_compare.py
#
# File Description: Proves that the hand-annotated submission files contain
#                   exactly the code sv2v generated, and nothing else. For every
#                   .v under the raw tree it strips comments, the restored
#                   `timescale directive and all whitespace from both the raw
#                   and the annotated copy, and requires the remaining token
#                   streams to be identical. Called by `make package_check`.
#
#                   Usage: strip_compare.py <raw_dir> <annotated_dir>
#
#                   A difference prints the file and the first differing token
#                   and exits 1. A file present in one tree and not the other
#                   is also a failure, so nothing can be added or lost.
#
# Global variables: None

import os
import re
import sys

# TOKEN: identifiers, sized/based numbers, strings, multi-char operators,
#        then any other single character
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|[A-Za-z_$][\w$]*|\d[\w\']*|\'[sS]?[bBoOdDhH][\w?]+|'
                   r'<<<|>>>|<=|>=|==|!=|===|!==|&&|\|\||<<|>>|\*\*|[^\s]')


def strip(text):
    # comments first, keeping string literals intact
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
    code = ''.join(out)
    # the restored `timescale is the one non-comment line allowed to differ
    code = re.sub(r'`timescale[^\n]*', '', code)
    return TOKEN.findall(code)


def files(root):
    found = set()
    for dirpath, _, names in os.walk(root):
        for name in names:
            if name.endswith('.v'):
                found.add(os.path.relpath(os.path.join(dirpath, name), root))
    return found


def main():
    raw_dir, ann_dir = sys.argv[1], sys.argv[2]
    raw, ann = files(raw_dir), files(ann_dir)
    bad = 0
    for rel in sorted(raw ^ ann):
        print(f"  MISSING  {rel}: present in only one tree")
        bad += 1
    for rel in sorted(raw & ann):
        a = strip(open(os.path.join(raw_dir, rel)).read())
        b = strip(open(os.path.join(ann_dir, rel)).read())
        if a == b:
            print(f"  SAME     {rel}  ({len(a)} tokens)")
            continue
        bad += 1
        k = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
        print(f"  DIFFERS  {rel}: token {k}: sv2v '{' '.join(a[k:k + 6])}' vs "
              f"annotated '{' '.join(b[k:k + 6])}'")
    print(f"--- {len(raw & ann) - bad + len(raw ^ ann) * 0} of {len(raw | ann)} files code-identical "
          f"to the sv2v output ---" if not bad else f"--- {bad} file(s) differ from the sv2v output ---")
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
