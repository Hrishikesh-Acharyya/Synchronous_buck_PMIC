# AI usage ledger

Every session in which an AI assistant (an LLM) did work in this phase: what it
was asked, what it was given, what it produced, how that was checked, and what
was accepted. Newest last. Findings go in `findings.md`; RTL change proposals in
`rtl_requests.md`.

Each entry: **Task** - **Inputs given to the AI** - **Produced** - **Checks
run** - **Accepted / rejected** - **Designer decisions**.

---

## L1 - 2026-11-12 - house-style and rulebook linter

**Task.** Build a linter for the mechanical rules of `docs/VERIFICATION_RULES.md`
and the coding standard, and measure the current tree against it.

**Inputs given to the AI.** The full repository (the linter reads every file;
no independence constraint applies to a style checker), the rulebook, and the
designer's rule decisions in conversation.

**Produced.**
- `verify/lint/sv_lint.py` - 20 rules, standard-library Python, report only.
- `verify/lint/RULES.md`, `verify/lint/exemptions.txt` (empty).
- `make lint_sv` / `make lint_sv_report` in `sim/mk/lint.mk`; `check_scripts`
  now also compiles `verify/*/*.py`.
- `verify/lint/baseline_2026-11-12.txt` - the first full report.

**How the rules were chosen.** The AI proposed 21 rules from the rulebook. The
designer removed four (`$stable`/`$changed` with `|=>`, `1'b1 |->`, `&counter`,
the "verilator" comment rule), asked for the stem-sharing rule to be relaxed,
kept `` `default_nettype wire ``, added the wrong-Filename check and the
spacing rules (begin / end on multi-line if / else; a blank line after every
begin and before every end; no exemption for single-line blocks). Three rules
that need a parser or judgement were deferred (RULES.md, "Not yet checked").

**Checks run.**
- Every rule's hits were sampled and read against the source before the
  numbers were reported. Four rules were wrong at first and were fixed
  (findings F1 to F4). After the fixes every sampled hit was genuine.
- `make check_scripts` clean.

**Result.** 57 files, 948 errors, 32 warnings, 0 exempted:

| Tree | Findings | Of which |
|---|---|---|
| `rtl-systemverilog/` | 227 | spacing 176, if/else without begin 28, module body indent 13, no comment on a block 9, file ending 1 |
| `sva/` | 119 | spacing 113, indent 2, file ending 2, no comment 1, if/else 1 |
| `tb/` | 634 | spacing 525, if/else 59, no comment 21, indent 17, WATCHDOG_NS 8, wrong Filename 3, file ending 1 |

Almost all of it is the new spacing standard, which every file predates. The
non-spacing findings are F5 to F9 in `findings.md`; the spacing backlog is F10. The checkers pass
every structural rule: PAC naming, covers per group, `note_failure()` reporting,
binds, reset properties, operators.

**Accepted / rejected.** Pending designer review of the baseline. Nothing in
`rtl-systemverilog/`, `sva/` or `tb/` was changed.

**Designer decisions.** Rule set as above. Pending: whether to fix the backlog
(and in what order), whether S4 (module body indentation) stays, and whether C1
should insist on one Purpose placement.
