# Lint reports

Each report is the full output of `make lint_evidence` (`tools/lint/sv_lint.py`;
the rules are in `tools/lint/RULES.md`). A change to the linter makes earlier
reports stale, so they are cleared and a new one is taken. The newest summary
is at the top.

## Totals: 1,681 findings caught and fixed

`2026-11-13_lint_original_code.txt` is the current linter (all 23 rules) run
on the code as it stood before the clean-up (commit 7ea100f), so every finding
is counted once, under the rules that now hold - the first rules' findings and
the later additions (S5, S6, H4) together. `2026-11-13_lint.txt` is the same
linter on the tree now: 0.

| Rule | What | RTL | sva | tb | Total |
|---|---|---:|---:|---:|---:|
| H2 | header names another file | 0 | 0 | 3 | 3 |
| H3 | file does not end with `` `default_nettype wire `` | 1 | 2 | 1 | 4 |
| H4 | template text left in a header (`pwm_stats_tb`) | 0 | 0 | 3 | 3 |
| C1 | block without a Purpose block inside it | 15 | 2 | 219 | 236 |
| S1 | multi-line if / else without begin / end | 28 | 1 | 59 | 88 |
| S2 | no blank line after a block opener | 136 | 94 | 390 | 620 |
| S3 | no blank line before a block closer | 98 | 88 | 375 | 561 |
| S5 | multi-line always / loop body without begin / end | 0 | 0 | 9 | 9 |
| S6 | block body not deeper than its opening line | 69 | 0 | 27 | 96 |
| P4 | two-edge property not guarded against reset | 0 | 31 | 0 | 31 |
| T1 | stimulus racing the clock edge | 0 | 0 | 14 | 14 |
| **Errors** | | **347** | **218** | **1,100** | **1,665** |
| S4 (warning) | module body indented | 13 | 2 | 1 | 16 |
| **All findings** | | **360** | **220** | **1,101** | **1,681** |

The other 12 rules (H1, K1, N1-N5, P1-P3, B1, B2) found nothing. 8 more
findings are exempted on purpose: the two templates' own `<PLACEHOLDER>`
markers (H4).

On top of the lint findings, the clean-up caught:

- **1 design bug** - `input_debounce` (R1 in `../rtl_change_requests.md`),
  with the **checker flaw** that hid it. See *Findings about the design*.
- **8 bugs in the linter itself.** See *Findings about the linter*.

For the record, the very first baseline (2026-11-12, 20 rules, before the
rules were settled with the designer) reported 948 errors and 32 warnings. Its
findings are inside the 1,681 above, except the 8 from the two rules dropped
since (no randomness in testbenches, `WATCHDOG_NS` form) and the S4 warnings
that were false positives.

## 2026-11-13_lint.txt: clean (tree at commit 27b5413)

57 files, 0 errors, 0 warnings. 8 findings exempted, all H4 on the two
templates' own `<PLACEHOLDER>` markers, each with its reason in
`tools/lint/exemptions.txt`. Every rule passes on the RTL, the checkers and the
testbenches.

### How the tree got there

From the first baseline (1563 errors, 32 warnings, 20 rules) to 0, with the
rule set growing to 23:

| Commit | What it did |
|---|---|
| 015b2f9 | Linter fixes the clean-up exposed (see *Findings about the linter*); the out-of-repo rulebook no longer cited. |
| 59a6fef | The `input_debounce` design fix - see *Findings about the design*. |
| 1db52d5 | P4: 31 two-edge checker properties guarded against reset. T1: 14 reset releases offset from the clock edge. |
| 4b1fbed | Layout across the RTL, checkers and testbenches (S1-S4, C1, H2, H3). |
| 200dc48 | New rules S5, S6, H4. |
| 27b5413 | Their fixes: 7 loop and always bodies wrapped in begin / end, block bodies indented. |

Every RTL layout commit leaves the sv2v output token-identical
(`verilog_check`, 17 of 17 files). After 4b1fbed the full `equiv_all` gate
passed: all 17 testbenches on the SystemVerilog source and on the sv2v output,
both cocotb suites included, 341 of 341 SVA covers hit, 0 assertion failures.
27b5413 changed no RTL token; the two testbenches whose code changed
(`pmic_top_tb`, `fault_arbiter_tb`) were rerun and pass in both flows.

### Findings about the design

| Finding | How it surfaced | Outcome |
|---|---|---|
| `input_debounce` never cleared its counter when `flag_out` flipped. If `flag_in` reversed on the next clock, the new window inherited the old count: an assert after a release qualified RELEASE_CLKS - 1 clocks early, and a symmetric instance (`en_from_switch`, the SPI filters) flipped back after one clock. | T1 moved the testbench's reset release off the clock edge. The race it removed had kept the qualification windows aligned so the corner never occurred; with it gone, `a_flag_out_qualified` and `a_ASSERT_and_RELEASE_work` failed. | Fixed in 59a6fef with the designer's approval - request R1 in `../rtl_change_requests.md`. A new directed group fails three times on the old RTL and passes on the new. |
| The checker shared the blind spot: `hold_count` carried over across a flip, and `a_flag_out_qualified` judged a flip against the target named by the current `flag_in`, which may already have reversed. | The same failures. | Fixed in 59a6fef with the RTL fix. |

### Findings about the testbenches and checkers

| Finding | Outcome |
|---|---|
| `pwm_stats_tb.sv`'s header was still the template's, description and all - H2 caught the file name, the description was wrong too. | Rewritten in 4b1fbed. H4 now catches template text. |
| 31 two-edge properties in the seven older checkers had no reset guard (P4). | Guarded in 1db52d5. |
| 14 reset releases raced the clock edge (T1). | Offset in 1db52d5 - and the source of the design finding above. |
| Purpose blocks shared by a timestamp one-liner and a multi-line monitor could not sit inside the monitor. | Each monitor now carries its own; the one-liner a `//` line. |

### Findings about the linter

Bugs the clean-up exposed in `sv_lint.py`, each fixed in 015b2f9 or 200dc48:

| Rule | Bug |
|---|---|
| S4 | Flagged continuation lines - port connections, wrapped expressions, enum members - as indented module items. |
| S4 | `assert property` raised the block depth and never lowered it, so a checker was not checked past its first assertion. |
| S4 | Did not know `clocking ... endclocking`. |
| S2 | Took a Purpose block after the module header for the header's own. |
| C1 | Did not walk over `integer` / `real` declarations above a run of one-line blocks. |
| P4 | Missed a reset helper named for the release (`clks_since_release`). |
| T1 | Would have flagged a drive through a clocking block, which takes the block's output skew. |
| S5 | While it was being written: took the `@(...)` after a loop's condition for header, and misjudged which line the header ends on. |
