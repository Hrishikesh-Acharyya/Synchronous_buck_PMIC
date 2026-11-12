# Findings register

Everything the AI-assisted phase found: defects in the RTL, checkers and
testbenches, and the AI's own mistakes (wrong rules, false alarms, rejected
proposals). Each finding names the ledger entry it came from.

Status: **open** (not acted on), **fixed** (with commit), **accepted** (judged
not a defect, with the reason), **AI error** (the AI's mistake, corrected).

| ID | Ledger | Where | What | Status |
|---|---|---|---|---|
| F1 | L1 | `sv_lint.py` rule P3 | **AI error.** The width table mis-read the identifier `dut_temp_dirty` as a type ending in `_t`, so six `$rose` / `$fell` on single-bit signals in `reg_file_sva.sv` were reported as multi-bit. Declarations are now matched only at the start of a line. | AI error, fixed before reporting |
| F2 | L1 | `sv_lint.py` rule N3 | **AI error.** The first version demanded a cover named like its assertion (`c_X` for `a_X`); 136 false alarms, since a group's covers are named for what they show. Now judged per PAC group. | AI error, fixed before reporting |
| F3 | L1 | `sv_lint.py` rule N3 | **AI error.** The per-group version then read the rule-line comment instead of the Purpose block, missing groups that document why they have no cover (the input-contract groups). Fixed; the documented decisions are now accepted, as rulebook §6 allows. | AI error, fixed before reporting |
| F4 | L1 | `sv_lint.py` rule C1 | **AI error.** The first version took the rulebook's "Purpose right after the opening line" literally and flagged 105 blocks, most of them testbench `initial begin` blocks with the Purpose block directly above. That placement is accepted pending a designer decision; 31 genuine findings remain. | AI error, fixed before reporting |
| F5 | L1 | `tb/protect/pwm_mask_tb.sv`, `tb/telemetry/pwm_stats_tb.sv`, `tb/template_tb.sv` | Header `Filename:` names the wrong file (`pwm_mask.sv`, `tb_template.sv`, `tb_template.sv`): scaffold debt. | open |
| F6 | L1 | `rtl-systemverilog/telemetry/fault_cause.sv`, `sva/bind_sva.sv`, `sva/sva_pkg.sv`, `tb/top/pmic_top/bind_top_only.sv` | File does not end with `` `default_nettype wire ``. (`bind_top_only.sv` was written by the AI.) | open |
| F7 | L1 | 8 testbenches | `WATCHDOG_NS` is an absolute time (e.g. `10_000.0`), not a multiple of `CLK_PERIOD_NS` (rulebook §1, scaffold debt) - including `tb/template_tb.sv`, which seeds every new testbench. | open |
| F8 | L1 | 31 procedural blocks (9 RTL, 1 checker, 21 testbench) | No comment at all, e.g. `reset_sync.sv:35`'s `always_ff`, the power-on blocks of `tb/top/pmic_top/pmic_top_harness.sv` (written by the AI). | open |
| F9 | L1 | 88 places (28 RTL) | Multi-line `if` / `else` without `begin` / `end`, e.g. `reset_sync.sv:36`, `supervisor.sv:146`. | open |
| F10 | L1 | 814 places | Spacing: no blank line after `begin` / before `end`. 344 are in `tb/pmic_top_tb.v` and 68 in `sva/telemetry/reg_file_sva.sv` - files the AI wrote or extended in earlier sessions - the rest across the tree. | open |
