# verif_automation/ai

AI-assisted verification: an AI agent judges, and later writes, verification
work, and the simulator decides whether that work holds. This folder holds
what the agent is asked to do and the scripts that run it. Every run kept as
a record - accepted or not - goes to `verif_automation/evidence/ai_runs/`.

## The agent

The agent is **Claude Code**, Anthropic's command-line coding agent. It runs
on the designer's own machine under the designer's existing subscription, with
no API key or per-token billing. The scripts here start it in its
non-interactive mode (`claude -p`), with the tools and paths each task
allows. (They do not use `--bare`: that mode needs an API key and ignores a
subscription login.)

Help with writing these scripts and tools is ordinary tooling work and is not
counted as an AI run. Only runs of the agent through `verif_automation/ai/`
count.

## Ground rules

1. **The agent never edits RTL.** `rtl-systemverilog/` and `rtl-verilog/`
   are read-only to it, enforced by the run script's permission settings, not
   by asking. If it thinks the RTL is wrong, it writes a change request to
   `verif_automation/evidence/rtl_change_requests.md`, and the designer decides.
2. **It writes only where its task allows.** Each task lists the paths it may
   write; every other path is denied.
3. **The simulator is the judge.** Nothing the agent writes is accepted on
   its own word. A new property must compile, pass on the real RTL and kill
   the mutants it was written for; a new test must pass and add coverage.
4. **Independence where it matters.** When the agent writes a checker or
   model, it is given the contract (`tools/contract`), not the RTL body, so it
   cannot copy the design's own mistakes. When it judges the design itself -
   the mutant triage - it reads the RTL and is kept away from the testbenches
   and checkers, so its judgement is about the design and not about what the
   tests happen to catch.
5. **Everything is disclosed.** Every run is logged: what it was asked, what
   it was given, what it produced, what checks ran, what was accepted or
   rejected and why, and the agent's own mistakes. A rejected or wrong output
   is logged the same as an accepted one.

## The first task: triage of mutants

Before any mutant is simulated, the agent sorts them
(`tasks/triage_mutants/TASK.md`). For each mutant that passes lint it answers
one question from the RTL: can this edit change the module's behaviour at its
ports?

- **plausible** - it can, or the agent is not certain it cannot. Simulated.
- **equivalent** - it cannot: unreachable code, a value nobody reads, two
  forms that are the same under an invariant. The agent must give the
  specific argument, and only a high-confidence verdict counts.

```
make triage                          the agent judges every mutant that passes lint
make mutate TRIAGE=build/mutation/triage.json
                                     simulate; AUDIT=all (default) also simulates
                                     the mutants judged equivalent
```

What keeps this honest:

- **The agent cannot change anything.** Its only tools are Read, Grep and
  Glob (`--tools`); every edit, command and network request is denied
  (`scripts/settings_readonly.json`, `--permission-mode dontAsk`), and no MCP
  server is loaded. Its answer comes back as structured data against
  `tasks/triage_mutants/schema.json`, not as files it writes.
- **Every answer is checked.** A verdict for exactly the mutants asked about,
  no others; a malformed answer is asked again once, then the chunk is left
  untriaged - and an untriaged mutant is simulated.
- **The verdicts are audited by simulation.** An equivalent mutant can never
  be killed. So the mutation run simulates the ones the agent called
  equivalent too, and each one a test kills is reported as a **triage error**
  with the agent's own reason beside it. `AUDIT=` lowers this to a sample or
  to none, in which case the unaudited ones are left out of the score and
  shown as `ai_equiv`.
- **The record is complete.** Each run's folder holds the exact command, every
  prompt sent and every raw response.

## Layout

| Path | What it holds |
|---|---|
| `tasks/triage_mutants/TASK.md` | the instructions the agent is given |
| `tasks/triage_mutants/schema.json` | the shape its answer must have |
| `scripts/triage_mutants.py` | the runner: lint screen, chunks, the `claude -p` calls, the checks, `triage.json`, the run record |
| `scripts/settings_readonly.json` | the permission settings for a read-only task |

A run's record is written to `build/ai_runs/<date>_<time>_triage_mutants/`
(not committed). `make triage_evidence` also copies it to
`evidence/ai_runs/` and adds a row to the ledger there.

## Running it

On the designer's machine, with Claude Code installed and logged in:

```
make triage DRY=1 MODULE=supervisor      write the prompts, call nothing
make triage MODULE=supervisor            one module
make triage                              all of them
make triage RESUME=build/ai_runs/<run>   continue a run a usage limit stopped
```

`MODEL=` passes a model name to the agent; the models actually used are read
from the responses and written into the run record.

## Planned tasks

| Task | The agent's job | Gate |
|---|---|---|
| `judge_survivors` | for each mutant that survived simulation: a gap (say what scenario would expose it) or equivalent (say why) | the designer's review; a named scenario can be simulated |
| `kill_mutants` | write the property or test that kills a surviving mutant | the mutant is killed and the real RTL still passes |
| `expand_checkers` | compare each module's checker against its extracted contract and add what is missing | new properties pass on the RTL and are covered |
| `shadow_model` | write an independent model of a module from its contract alone, for differential testing | differences are explained, and each one is a model error or a design bug |
| `close_coverage` | read the coverage holes and write tests or constraints to reach them | the bins are hit, and no existing test breaks |
| `mine_traces` | judge candidate invariants from `verif_automation/tools/trace_mining` | accepted ones become properties that pass |
