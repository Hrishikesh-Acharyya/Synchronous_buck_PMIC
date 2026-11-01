#
# Filename:         Makefile
#
# File Description: Lint, simulation, equivalence, the Verilog split and
#                   synthesis for the PMIC supervisor. Run from sim/.
#                   `make help` lists every target, grouped; ../COMMANDS.md
#                   lists them with examples.
#
#                   This file holds the one thing edited as the design grows -
#                   the TESTBENCHES list - and includes the rest from mk/:
#                     mk/config.mk   tools, paths, run modes, colours
#                     mk/sources.mk  RTL and SVA file lists, Verilator flags
#                     mk/tb.mk       module testbenches and the suites
#                     mk/top.mk      the integration testbench, both builds
#                     mk/lint.mk     lint, script checks
#                     mk/syn.mk      sv2v conversion and yosys synthesis
#                     mk/verilog.mk  rtl-verilog, SPI-less variants, bundles
#                     mk/util.mk     doctor, ci, new_tb, clean, help
#
#                   Every testbench target is GENERATED from TESTBENCHES -
#                   adding a module is one line there, not four hand-copied
#                   blocks. The build-run-gate logic lives in
#                   scripts/run_tb.sh, the suite table in scripts/report.sh.
#
#                   Suite runs parallelise: `make -j8 tb_all`. Each testbench
#                   has its own build directory per flow, so tb_ and equiv_
#                   runs of the same module never collide.
#
# Global variables: TESTBENCHES - the module list every per-module target is
#                                 generated from
#                   QUIET, NOFAIL, STRICT, WAVES, SPLIT, COLOR - run modes,
#                                 see mk/config.mk and `make help`

SHELL := /bin/bash

# --output-sync: under -j, hold each target's output until it finishes so
#                parallel runs do not interleave line by line. No effect on
#                a serial run.
MAKEFLAGS += --output-sync=target --no-print-directory

# all: kept as the default goal so a bare `make` (and anything in CI that
#      calls it) still means lint.
.DEFAULT_GOAL := all

# ============================================================
# TESTBENCHES - the single source of truth
# ============================================================
# One entry per module, as <rtl subfolder>/<module>. From each entry the
# Makefile derives the testbench file ../tb/<entry>_tb.sv, the top
# <module>_tb, and the targets tb_<module>, equiv_<module>, wave_<module>,
# view_<module> and cov_<module>. `make new_tb M=<group>/<module>` scaffolds
# a new testbench from ../tb/template_tb.sv and prints the line to add here.
TESTBENCHES := clk_rst/reset_sync \
               inputs/input_sync \
               inputs/input_debounce \
               protect/pwm_mask \
               protect/soft_start \
               protect/hiccup_timer \
               protect/strike_counter \
               status/pgood_gen \
               status/timestamp \
               status/fault_LED \
               telemetry/pwm_stats \
               telemetry/fault_cause

# ============================================================
# The rest, in dependency order
# ============================================================
MK := mk
include $(MK)/config.mk
include $(MK)/sources.mk
include $(MK)/tb.mk
include $(MK)/top.mk
include $(MK)/lint.mk
include $(MK)/syn.mk
include $(MK)/verilog.mk
include $(MK)/util.mk
