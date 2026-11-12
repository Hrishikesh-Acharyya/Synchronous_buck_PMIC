# verify/ - AI-assisted verification

The hand-written verification of the supervisor is complete and closed (see
the top-level README). This folder holds the next phase: tools that check the
verification itself, built and run with the help of an AI assistant (an LLM),
and the record of exactly what the AI did.

## Ground rules

- **The simulator and the scripts decide; the AI proposes.** Nothing the AI
  writes is accepted on its say-so: it must pass the same gates as hand-written
  work, and its results are reproducible with the commands given beside them.
- **The AI never edits the RTL.** RTL changes are proposed in
  `ai/rtl_requests.md` and made only with the designer's approval
  (`docs/VERIFICATION_RULES.md` §0).
- **The AI's inputs are restricted where independence matters.** A checker or
  shadow written "from the contract" is given only the extracted contract, not
  the RTL body, so it cannot copy the implementation's mistakes.
- **Full disclosure.** Every AI session is logged in `ai/ledger.md`: what it
  was given, what it produced, which checks ran on it, what was accepted and
  what was rejected. Findings, including the AI's own mistakes, are in
  `ai/findings.md`.

## Layout

| Path | What |
|---|---|
| `lint/` | `sv_lint.py`, the house-style and rulebook linter; `RULES.md`, its rules; `exemptions.txt`, accepted exceptions; `baseline_*.txt`, its reports |
| `ai/ledger.md` | one entry per AI session |
| `ai/findings.md` | everything found: RTL, checker and testbench defects, and the AI's own mistakes |
| `ai/rtl_requests.md` | proposed RTL changes awaiting the designer's decision |

Planned, in order: a contract extractor and a mutation-testing runner, then
checker expansion from the contract, shadow models for differential testing,
coverage closure, and trace mining. Each gets its own folder here when it
starts.

## Commands

From `sim/`: `make lint_sv`, `make lint_sv_report` (see `lint/RULES.md`).
