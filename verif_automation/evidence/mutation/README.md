# Mutation records

One record per module, added to by every step run on it and never cut: the AI writing mutants (`make ai_mutants`), a mutation run (`make mutate`), the AI judging survivors (`make judge`), and the designer's decisions (`make decide`). `<module>.json` is the record; `<module>.md` is the same record written out to be read. This table is each module's present state, rewritten from the records.

| Module | Mutants | AI-written | Killed | Lint | Covers | Timeout | Survived | Not run | Score | Survivors not decided | Score, explained survivors out | Steps: AI wrote / mutation / AI judged | Last step |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| [`fault_cause`](fault_cause.md) | 23 | 23 | 0 | 0 | 0 | 0 | 0 | 23 | - | 0 | - | 2 / 0 / 0 | 2026-11-14 664452d |
| [`reset_sync`](reset_sync.md) | 22 | 2 | 17 | 5 | 0 | 0 | 0 | 0 | 100.0% | 0 | 100.0% | 3 / 1 / 0 | 2026-11-14 664452d |

Score = (killed + lint + covers + timeout) / (those + survived), over each mutant's newest outcome. The aim is no undecided survivor, not 100% - see `tools/mutation/README.md`.
