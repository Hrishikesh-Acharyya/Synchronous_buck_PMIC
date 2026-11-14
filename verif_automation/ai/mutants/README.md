# ai/mutants

The mutants written by the AI step (`make ai_mutants`) and accepted by its
gate - one file per module, `<module>.json`. `make mutate` runs every mutant
here beside the mechanical ones, as operator `AIM`. How they are written and
gated is in `../README.md`.

These files are the fixed input of a mutation run: commit them, so that the
run gives the same result every time. The folder is empty until the first
`make ai_mutants`.

## One entry

| Field | What it is |
|---|---|
| `key` | the mutant's number within its module; its id is `<module>.<line>.AIM.<key>` |
| `line` | the line the replaced lines started on when the mutant was written |
| `before` | the lines replaced, as they stand in the file. Unchanged lines are kept around the edit where needed, so that the text stands at one place only |
| `after` | the lines put there |
| `category` | the kind of fault (`../tasks/write_mutants/TASK.md` lists them) |
| `description` | the fault, in the design's terms |
| `reason` | what changes at the module's ports, and when |
| `run` | the run that wrote it (`build/ai_runs/`, or `evidence/ai_runs/` if saved) |

A mutant is placed by its `before` text, not by `line`: it follows its lines
when the file above them changes. If the lines themselves change, it can no
longer be placed; `make mutants` names it as left out.

## Changing the set

- Remove a mutant: `make drop IDS=<id> WHY="the reason"`. It moves the entry
  to the file's `withdrawn` list - no longer run, and refused by the gate if
  the agent proposes the same edit again - and marks it withdrawn in the
  module's record with your reason. Do not delete an entry by hand: the
  record would not know why it went.
- Add more: `make ai_mutants MODULE=<module>` again. New mutants take the
  next keys.
- An entry may be written by hand in the same form - it is run like any
  other. Check it with `make mutants_check OPERATORS=AIM`.
