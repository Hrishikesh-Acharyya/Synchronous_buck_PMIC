#!/usr/bin/env python3
#
# Filename:         summarize.py
#
# File Description: Tabulates every place-and-route run: metrics.txt, facts
#                   parsed from the flow log (routing iterations, wire length,
#                   vias, buffers inserted) and the power total. Writes
#                   summary.tsv next to the runs directory and prints one line
#                   per run.
#
#                   Usage: summarize.py [runs_dir]   (default: work/runs)
#
# Global variables: None
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "work", "runs")
SLOT = 180.0 * 115.0


def metrics(path):
    m = {}
    if os.path.exists(path):
        for line in open(path):
            if ' = ' in line:
                k, v = line.rstrip('\n').split(' = ', 1)
                m[k.strip()] = v.strip()
    return m


def log_facts(path):
    f = {}
    if not os.path.exists(path):
        return f
    t = open(path, errors='replace').read()
    it = re.findall(r'Start (\d+)\w* optimization iteration', t)
    f['drt_iters'] = str(int(it[-1]) + 1) if it else ''
    v = re.findall(r'Number of violations = (\d+)', t)
    f['drt_final_viol'] = v[-1] if v else ''
    wl = re.findall(r'Total wire length = ([\d.]+) um', t)
    f['wirelength_um'] = wl[-1] if wl else ''
    vias = re.findall(r'Total number of vias = (\d+)', t)
    f['vias'] = vias[-1] if vias else ''
    el = re.findall(r'Complete detail routing\.\n\[INFO DRT-0267\] cpu time = [\d:]+, elapsed time = ([\d:]+)', t)
    f['drt_elapsed'] = el[-1] if el else ''
    grt = re.search(r'Total\s+(\d+)\s+(\d+)\s+([\d.]+)%\s+(\d+)\s*/\s*(\d+)\s*/\s*(\d+)', t)
    if grt:
        f['grt_usage_pct'] = grt.group(3)
        f['grt_overflow'] = grt.group(4)
    buf = re.search(r'Inserted (\d+) buffers', t)
    f['repair_buffers'] = buf.group(1) if buf else ''
    hold = re.findall(r'Inserted (\d+) hold buffers', t)
    f['hold_buffers'] = hold[-1] if hold else ''
    rsz = re.search(r'Resized (\d+) instances', t)
    f['resized'] = rsz.group(1) if rsz else ''
    clkbuf = re.search(r'Created (\d+) clock buffers', t)
    f['cts_buffers'] = clkbuf.group(1) if clkbuf else ''
    fill = re.search(r'Placed (\d+) filler instances', t)
    f['fillers'] = fill.group(1) if fill else ''
    return f


def power(path):
    if not os.path.exists(path):
        return ''
    for line in open(path):
        if line.startswith('Total'):
            parts = line.split()
            try:
                return '%.1f' % (float(parts[4]) * 1e6)
            except (IndexError, ValueError):
                return ''
    return ''


COLS = ['run', 'die_um', 'slot_x', 'core_area_um2', 'util_after_taps', 'util_after_cts',
        'util_final', 'result', 'drt_iters', 'drc_violations', 'wirelength_um', 'vias',
        'worst_setup_slack_ns', 'worst_hold_slack_ns', 'power_uW', 'repair_buffers',
        'hold_buffers', 'cts_buffers', 'fillers', 'grt_usage_pct', 'grt_overflow',
        'drt_elapsed', 'elapsed_s']

rows = []
for d in sorted(os.listdir(ROOT)):
    p = os.path.join(ROOT, d)
    if not os.path.isdir(p):
        continue
    m = metrics(os.path.join(p, 'metrics.txt'))
    m.update(log_facts(os.path.join(p, 'stdout.log')))
    m['power_uW'] = power(os.path.join(p, 'power.rpt'))
    m['run'] = d
    if 'die_area_um2' in m:
        m['slot_x'] = '%.2f' % (float(m['die_area_um2']) / SLOT)
    rows.append(m)

with open(os.path.join(ROOT, '..', 'summary.tsv'), 'w') as fh:
    fh.write('\t'.join(COLS) + '\n')
    for r in rows:
        fh.write('\t'.join(r.get(c, '') for c in COLS) + '\n')

for r in rows:
    print(' | '.join('%s=%s' % (c, r.get(c, '')) for c in COLS if r.get(c, '')))
