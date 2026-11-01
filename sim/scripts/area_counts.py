#!/usr/bin/env python3
#
# Filename:         area_counts.py
#
# File Description: Reduces a yosys `stat -liberty` table to the figures the
#                   Silicluster area log records: flop count, mapped
#                   combinational cell count, cell area, die area at an assumed
#                   utilisation, and the ratio against the standard digital
#                   slot. Called at the end of the syn_area targets in
#                   sim/Makefile so every run prints one comparable line.
#
#                   Usage: area_counts.py <area_summary.txt> [label]
#
#                   A cell counts as sequential when its sky130 name starts
#                   with df, dl, sdf or edf (flip-flops and latches); every
#                   other mapped sky130 cell is combinational. Cell area is the
#                   yosys "Chip area" figure, the sum of cell footprints, and
#                   is never quoted as die area.
#
# Global variables: UTILISATION - assumed placement utilisation for die area
#                   SLOT_UM2    - Silicluster v3 standard slot, 180 x 115 um

import re
import sys

# UTILISATION: carried over from the earlier estimate on main so the trend is
#              comparable. Real P&R utilisation will differ.
UTILISATION = 0.57
# SLOT_UM2: the standard digital project area from the call, section 7
SLOT_UM2 = 180 * 115


def main():
    path = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else path
    seq_cells = comb_cells = 0
    chip_area = None
    for line in open(path):
        cell_row = re.match(r"\s+(\d+)\s+\S+\s+(sky130_fd_sc_\w+)\s*$", line)
        if cell_row:
            count, name = int(cell_row.group(1)), cell_row.group(2)
            if re.search(r"__(df|dl|sdf|edf)", name):
                seq_cells += count
            else:
                comb_cells += count
            continue
        area_row = re.search(r"Chip area for module .*:\s*([0-9.]+)", line)
        if area_row:
            chip_area = float(area_row.group(1))
    if chip_area is None:
        print(f"{label}: no Chip area line in {path}")
        sys.exit(1)
    die_area = chip_area / UTILISATION
    print(f"--- {label}: flops {seq_cells}, comb cells {comb_cells}, "
          f"cell area {chip_area:,.0f} um2, die @{UTILISATION:.0%} "
          f"{die_area:,.0f} um2, {die_area / SLOT_UM2:.2f}x slot ---")


if __name__ == "__main__":
    main()
