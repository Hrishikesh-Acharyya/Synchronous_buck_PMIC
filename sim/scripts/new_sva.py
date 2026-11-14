#!/usr/bin/env python3
#
# Filename:         new_sva.py
#
# File Description: `make new_sva M=<group>/<module>`: creates
#                   sva/<group>/<module>_sva.sv from sva/template_sva.sv. Reads
#                   the RTL module's header in rtl-systemverilog/ and copies its
#                   parameters and ports in - every port, outputs included,
#                   becomes a checker input of the same width, so the bind can
#                   connect them all with (.*). Then prints the bind line to
#                   add to sva/bind_sva.sv, with every parameter passed
#                   through. The package is imported only if the DUT imports
#                   it, as in the existing checkers. Refuses to overwrite an
#                   existing checker.
#
#                   M may also name a module with no group folder
#                   (supervisor). The Makefile compiles only sva/<group>/*.sv,
#                   so that checker goes to sva/top/<module>_sva.sv, and the
#                   script says so.
#
#                   Usage: new_sva.py <group>/<module>|<module>   (run from sim/)
#
# Global variables: COLOR - 1 for ANSI colour

import os
import re
import sys

COLOR = os.environ.get('COLOR') == '1'
RED, GRN, YEL, OFF = ('\033[31m', '\033[32m', '\033[33m', '\033[0m') if COLOR else ('', '', '', '')

SV_DIR = '../rtl-systemverilog'
SVA_DIR = '../sva'
TEMPLATE = os.path.join(SVA_DIR, 'template_sva.sv')


def die(msg):
    print(f'{RED}xx {msg}{OFF}', file=sys.stderr)
    sys.exit(1)


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    return re.sub(r'//[^\n]*', ' ', text)


def split_top(text):
    """Split on commas that are not inside (), [] or {}."""
    parts, depth, cur = [], 0, []
    for ch in text:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    if ''.join(cur).strip():
        parts.append(''.join(cur))
    return [' '.join(p.split()) for p in parts if p.strip()]


def balanced(text, start):
    """text[start] is '('; return the index of its matching ')'."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    die('unbalanced parentheses in the module header')


def parse_header(path, module):
    src = strip_comments(open(path).read())
    m = re.search(r'\bmodule\s+' + re.escape(module) + r'\b', src)
    if not m:
        die(f'no module {module} in {path}')
    i = m.end()
    imports = re.match(r'\s*(import\s+[\w:*,\s]+;\s*)*', src[i:])
    has_import = 'pmic_types_pkg' in imports.group(0)
    i += imports.end()
    params = []
    if src[i:].lstrip().startswith('#'):
        j = src.index('(', src.index('#', i))
        k = balanced(src, j)
        params = [re.sub(r'^parameter\s+', '', p) for p in split_top(src[j + 1:k])]
        i = k + 1
    j = src.index('(', i)
    k = balanced(src, j)
    ports = []
    for p in split_top(src[j + 1:k]):
        pm = re.match(r'(input|output|inout)\s+(.*)$', p)
        if not pm:
            die(f'cannot read port declaration: {p}')
        rest = re.sub(r'^(wire|var|reg)\s+', '', pm.group(2))
        name = rest.split()[-1]
        decl = rest[:-len(name)].strip()
        rng = re.search(r'\[.*\]', decl)
        dtype = re.sub(r'\[.*\]', '', decl).strip()
        ports.append((name, dtype, rng.group(0) if rng else '', pm.group(1)))
    return params, ports, has_import


def main():
    if len(sys.argv) != 2:
        die('usage: new_sva.py <group>/<module>')
    entry = sys.argv[1].strip('/')
    if not re.fullmatch(r'([A-Za-z0-9_]+/)?[A-Za-z_]\w*', entry):
        die(f"expected <group>/<module> or <module>, e.g. protect/soft_start - got '{entry}'")
    module = entry.split('/')[-1]
    rtl = os.path.join(SV_DIR, entry + '.sv')
    group = entry.split('/')[0] if '/' in entry else 'top'
    dest = os.path.join(SVA_DIR, group, module + '_sva.sv')

    if not os.path.isfile(TEMPLATE):
        die(f'no template at {TEMPLATE}')
    if not os.path.isfile(rtl):
        die(f'no RTL at {rtl}')
    if os.path.exists(dest):
        die(f'{dest} already exists - not overwritten')

    params, ports, has_import = parse_header(rtl, module)

    width = max([len(t or 'logic') + len(r) + 1 for _, t, r, _ in ports] + [8])
    port_lines = []
    for name, dtype, rng, direction in ports:
        typ = 'logic' if dtype in ('', 'logic', 'bit') else dtype
        decl = f'{typ} {rng}'.strip()
        note = '  // DUT output' if direction == 'output' else ''
        port_lines.append(f'    input  wire {decl:<{width}} {name},{note}')
    if port_lines:  # the last port takes no comma: the internals below are commented out
        last = port_lines[-1]
        port_lines[-1] = last.replace(',', '', 1) if ',  //' in last else last.rstrip(',')

    text = open(TEMPLATE).read()
    # Mirror the DUT: import the package only if it does. An import the DUT
    # does not have would make a parameter such as ON_TIME_W hide the package
    # constant of the same name - a VARHIDDEN warning, fatal under -Wall.
    import_line = [l for l in text.split('\n') if 'import pmic_types_pkg::*;' in l][0]
    text = text.replace(import_line + '\n', '    import pmic_types_pkg::*;\n' if has_import else '')
    text = text.replace('<MODULE>', module)
    text = text.replace('template_sva.sv', module + '_sva.sv')
    if params:
        text = text.replace('    <PARAMETERS>', ',\n'.join(f'    parameter {p}' for p in params))
    else:  # no parameters: drop the #( ) block entirely
        text = text.replace('#(\n    <PARAMETERS>\n)(', '(')
    text = text.replace('    <PORTS>', '\n'.join(port_lines))

    os.makedirs(os.path.dirname(dest), exist_ok=True)
    open(dest, 'w').write(text)
    print(f'{GRN}-- created {dest}{OFF}')
    print(f'   {len(params)} parameter(s) and {len(ports)} port(s) copied from {rtl}')
    if group == 'top':
        print(f'{YEL}!! {module} has no group folder; its checker is in sva/top/ so the Makefile compiles it{OFF}')

    pnames = [re.split(r'[\s=]', re.sub(r'^(int|bit|logic|integer|int unsigned)(\s*\[.*?\])?\s+', '', p))[0]
              for p in params]
    print('   next: write the PAC groups, then add this to sva/bind_sva.sv:\n')
    if pnames:
        print(f'bind {module} {module}_sva #(')
        print(',\n'.join(f'    .{n}({n})' for n in pnames))
        print(') u_sva (.*);')
    else:
        print(f'bind {module} {module}_sva u_sva (.*);')
    print(f'\n   (internals: add .dut_<signal>(<signal>) before .* in the bind)')
    print(f'   and run its testbench, e.g.  make tb_{module}')


if __name__ == '__main__':
    main()
