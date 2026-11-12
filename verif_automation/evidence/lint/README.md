# Lint reports

Each report is the full output of `make lint_sv_evidence` (`sv_lint.py`; the
rules are in `verif_automation/tools/lint/RULES.md`). The newest summary is at the top.

## 2026-11-12_lint.txt: first baseline (commit 5630fce)

57 files, 948 errors, 32 warnings, 0 exempted. No fixes had been made yet, so
this is the starting point.

| Rule | What | RTL | sva | tb |
|---|---|---:|---:|---:|
| H2 | Filename line does not match the file | 0 | 0 | 3 |
| H3 | file does not end with `` `default_nettype wire `` | 1 | 2 | 1 |
| C1 | procedural block without a Purpose comment | 9 | 1 | 21 |
| S1 | multi-line if / else without begin / end | 28 | 1 | 59 |
| S2 | no blank line after begin or the module header | 84 | 59 | 267 |
| S3 | no blank line before end or endmodule | 92 | 54 | 258 |
| S4 (warning) | module body indented | 13 | 2 | 17 |
| T2 | `WATCHDOG_NS` not written from `CLK_PERIOD_NS` | - | - | 8 |

Every other rule (H1, K1, N1-N5, P1-P3, T1, B1) found nothing.

Findings that are more than spacing:

- **H2:** `tb/protect/pwm_mask_tb.sv` says `pwm_mask.sv`;
  `tb/telemetry/pwm_stats_tb.sv` and `tb/template_tb.sv` say
  `tb_template.sv`. The last two are copies of the template that kept its
  name.
- **H3:** `rtl-systemverilog/telemetry/fault_cause.sv`, `sva/bind_sva.sv`,
  `sva/sva_pkg.sv`, `tb/top/pmic_top/bind_top_only.sv`.
- **T2:** seven unit testbenches and the template use a fixed
  `WATCHDOG_NS = 10_000.0` or `20_000.0`; `tb/pmic_top_tb.v` uses
  milliseconds.
- **C1 and S1:** listed in full in the report.

The RTL findings are for the designer to decide: see request R1 in
`../rtl_change_requests.md`.
