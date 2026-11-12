# AI run findings

Everything an agent run turned up, good or bad. Each finding links to the run
in `ledger.md` that produced it.

Kinds:

- **design bug:** the RTL is wrong. It is raised as a request in
  `../rtl_change_requests.md`.
- **verification gap:** the handwritten suite missed something, such as a
  surviving mutant, an unchecked contract clause or an unreached bin.
- **agent error:** the agent's output was wrong: a property that fails on
  correct RTL, a wrong claim, a mutant called equivalent that was not, or an
  attempt to write outside its allowed paths.
- **rejected:** output that was correct but not taken, with the reason.

| ID | Run | Kind | What was found | Evidence | Outcome |
|---|---|---|---|---|---|

None yet.
