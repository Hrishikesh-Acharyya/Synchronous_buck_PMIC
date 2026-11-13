# Lint reports

Each report is the full output of `make lint_evidence` (`tools/lint/sv_lint.py`;
the rules are in `tools/lint/RULES.md`). A change to the linter makes earlier
reports stale, so they are cleared and a new one is taken. The newest summary
is at the top.

## 2026-11-13_lint.txt: clean (tree at commit 4b1fbed)

57 files, 0 errors, 0 warnings, 0 exempted. Every rule passes on the RTL, the
checkers and the testbenches.

How the tree got there, from the previous report (1563 errors, 32 warnings;
cleared because the linter changed):

| Commit | What it fixed |
|---|---|
| 015b2f9 | The linter itself. Rule fixes the clean-up exposed: S4 flagged continuation lines (port connections, wrapped expressions) and clocking blocks, and stopped checking a checker after its first `assert property`; S2 tied a comment after a module header to the header; C1 did not walk over `integer` / `real` declarations; P4 missed a helper named for the reset's release; T1 would have flagged drives through a clocking block. |
| 59a6fef | A design bug the race-free reset exposed in `input_debounce`, fixed with the designer's approval - see that commit. |
| 1db52d5 | P4: 31 two-edge checker properties guarded against reset. T1: 14 reset releases offset from the clock edge. |
| 4b1fbed | Layout across the RTL, checkers and testbenches (S1-S4, C1, H2, H3). No logic change; the RTL's sv2v output is token-identical. |

Checked after these commits: Verilator lint in both builds, the script check,
`verilog_check` (17 of 17 files code-identical to sv2v), and the full
`equiv_all` gate - all 17 testbenches pass on the SystemVerilog source and on
the sv2v output, both cocotb suites included; 341 of 341 SVA covers hit, 0
assertion failures.
