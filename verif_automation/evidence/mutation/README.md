# Mutation records

One record per module, added to by every step run on it and never cut: the AI writing mutants (`make ai_mutants`), a mutation run (`make mutate`), the AI judging survivors (`make judge`), and the designer's decisions (`make decide`). `<module>.json` is the record; `<module>.md` is the same record written out to be read. This table is each module's present state, rewritten from the records.

| Module | Mutants | AI-written | Killed | Lint | Covers | Timeout | Survived | Not run | Score | Survivors not decided | Score, explained survivors out | Steps: AI wrote / mutation / AI judged | Last step |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| [`fault_cause`](fault_cause.md) | 23 | 23 | 0 | 0 | 0 | 0 | 0 | 23 | - | 0 | - | 2 / 0 / 0 | 2026-11-14 664452d |
| [`hiccup_timer`](hiccup_timer.md) | 55 | 12 | 38 | 11 | 0 | 0 | 6 | 0 | 89.1% | 0 | 98.0% | 6 / 1 / 1 | 2026-11-15 a1dc229 |
| [`input_debounce`](input_debounce.md) | 85 | 16 | 73 | 3 | 2 | 0 | 7 | 0 | 91.8% | 0 | 95.1% | 4 / 1 / 1 | 2026-11-15 f71cb1f |
| [`input_sync`](input_sync.md) | 27 | 5 | 20 | 7 | 0 | 0 | 0 | 0 | 100.0% | 0 | 100.0% | 3 / 1 / 0 | 2026-11-14 217b430 |
| [`pgood_gen`](pgood_gen.md) | 90 | 18 | 36 | 12 | 21 | 0 | 21 | 0 | 76.7% | 0 | 80.2% | 8 / 1 / 1 | 2026-11-17 34b8ec6 |
| [`pwm_mask`](pwm_mask.md) | 71 | 11 | 32 | 10 | 7 | 0 | 22 | 0 | 69.0% | 0 | 75.4% | 3 / 1 / 1 | 2026-11-15 e6d9ec9 |
| [`pwm_stats`](pwm_stats.md) | 123 | 23 | 109 | 10 | 0 | 0 | 4 | 0 | 96.7% | 0 | 97.5% | 6 / 1 / 1 | 2026-11-17 58da85b |
| [`reset_sync`](reset_sync.md) | 22 | 2 | 17 | 5 | 0 | 0 | 0 | 0 | 100.0% | 0 | 100.0% | 3 / 1 / 0 | 2026-11-14 664452d |
| [`strike_counter`](strike_counter.md) | 151 | 33 | 101 | 28 | 0 | 0 | 22 | 0 | 85.4% | 0 | 92.1% | 5 / 1 / 1 | 2026-11-17 530e2fe |
| [`timestamp`](timestamp.md) | 46 | 5 | 42 | 0 | 0 | 0 | 4 | 0 | 91.3% | 0 | 97.7% | 2 / 1 / 1 | 2026-11-15 05405e5 |

Score = (killed + lint + covers + timeout) / (those + survived), over each mutant's newest outcome. The aim is no undecided survivor, not 100% - see `tools/mutation/README.md`.
