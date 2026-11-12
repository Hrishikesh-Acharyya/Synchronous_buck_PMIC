# RTL change requests

The AI does not edit `rtl-systemverilog/`, `rtl-verilog/` or `Build/`. When AI-
assisted work finds something in the RTL worth changing, it is proposed here
and waits for the designer's decision (`docs/VERIFICATION_RULES.md` §0).

Each request: **file and line** - **trigger** (what shows the problem) -
**effect** - **proposed change** - **status** (proposed / approved / rejected,
with the designer's reason) - **commit** once made.

---

## R1 - style findings in the RTL (from ledger L1)

**Files.** All of `rtl-systemverilog/`, per `verify/lint/baseline_2026-11-12.txt`.

**Trigger.** `make lint_sv`: 227 findings in the RTL - spacing (176), multi-line
if / else without begin / end (28), module body indentation (13, warning), a
procedural block without a comment (9), `fault_cause.sv` not ending with
`` `default_nettype wire `` (1).

**Effect.** Style only; no change in behaviour. A begin / end added to an
if / else and blank lines change no logic.

**Proposed change.** Fix them in one pass per file, then confirm nothing
changed: `make verilog_check` (rtl-verilog code-identical), the full regression
(`make -j8 equiv_all STRICT=1`) and synthesis cell counts unchanged.

**Status.** proposed - waiting for the designer.
