# Lint reports

Each report is the full output of `make lint_evidence` (`tools/lint/sv_lint.py`;
the rules are in `tools/lint/RULES.md`). A change to the linter makes earlier
reports stale, so they are cleared and a new baseline is taken. The newest
summary is at the top.

## 2026-11-12_lint.txt: baseline (linter at commit fe2e574)

57 files, 1563 errors, 32 warnings, 0 exempted. Nothing had been fixed yet.

| Rule | What | RTL | sva | tb |
|---|---|---:|---:|---:|
| H2 | Filename line does not match the file | 0 | 0 | 3 |
| H3 | file does not end with `` `default_nettype wire `` | 1 | 2 | 1 |
| C1 | block without a Purpose block inside it (69 of these have one above the block instead) | 15 | 2 | 221 |
| S1 | multi-line if / else without begin / end | 28 | 1 | 59 |
| S2 | no blank line after a block opener or a leading Purpose block | 136 | 95 | 391 |
| S3 | no blank line before a block closer | 98 | 88 | 375 |
| S4 (warning) | module body indented | 13 | 2 | 17 |
| P4 | two-edge property not guarded against reset | 0 | 33 | 0 |
| T1 | stimulus right after `@(posedge clk)` with no `#(DRIVE_OFFSET_NS)` | 0 | 0 | 14 |

Every other rule (H1, K1, N1-N5, P1-P3, B1, B2) found nothing.

Findings that are more than layout:

- **H2:** `tb/protect/pwm_mask_tb.sv` says `pwm_mask.sv`;
  `tb/telemetry/pwm_stats_tb.sv` and `tb/template_tb.sv` say
  `tb_template.sv`.
- **H3:** `rtl-systemverilog/telemetry/fault_cause.sv`, `sva/bind_sva.sv`,
  `sva/sva_pkg.sv`, `tb/top/pmic_top/bind_top_only.sv`.
- **P4:** 33 properties in seven checkers (`input_debounce`, `pwm_mask`,
  `fault_LED`, `pgood_gen`, `timestamp`, `reg_file`, `spi_slave`) use `|=>`
  or `$past` with only `disable iff (!rst_n)`. The checkers written later
  (`hiccup_timer`, `soft_start`, `strike_counter`, `fault_cause`, the top
  level) carry `$past(rst_n)` or `out_of_reset` and pass.
- **T1:** all 14 are the `do_reset` task (or reset release in group 1),
  which releases `rst_n` straight after `@(posedge clk)`. It is the same code
  in each testbench, copied from `tb/template_tb.sv`.
