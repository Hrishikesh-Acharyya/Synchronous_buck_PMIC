# Lint reports

Each report is the full output of `make lint_evidence` (`tools/lint/sv_lint.py`;
the rules are in `tools/lint/RULES.md`). A change to the linter makes earlier
reports stale, so they are cleared and a new one is taken. The newest summary
is at the top.

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
