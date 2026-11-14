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

## The first task: judging mutants

A mutant is the design with one small edit (`tools/mutation`). The agent's
job is one question per mutant, answered from the RTL
(`tasks/triage_mutants/TASK.md`): can this edit change the module's behaviour
at its ports?

- **plausible** - it can, or the agent is not certain it cannot.
- **equivalent** - it cannot: unreachable code, a value nobody reads, two
  forms that are the same under an invariant. The agent must give the
  specific argument, and only a high-confidence verdict counts.

It can be asked at two points.

**After the tests - recommended.** Run the mutation tests first; they need no
AI. Then have the agent judge only the survivors: each is a real gap in the
verification (plausible) or harmless (equivalent).

```
make mutate                 simulate every mutant - an hour or two, no AI
make judge                  the agent judges the survivors of that run
```

**Before the tests.** The agent judges every mutant that passes lint, and the
mutation run can skip the ones it called equivalent.

```
make triage                 the agent judges every mutant that passes lint
make mutate TRIAGE=build/mutation/triage.json
```

Why after is better: the agent can only ever remove the mutants that change
nothing, and those are few. The plausible ones - most of them - have to be
simulated either way, so judging first saves little simulation and costs
about ten times the requests (roughly 1,500 mutants against a hundred or so
survivors).

What keeps either order honest:

- **The agent cannot change anything.** Its only tools are Read, Grep and
  Glob (`--tools`); every edit, command and network request is denied
  (`scripts/settings_readonly.json`, `--permission-mode dontAsk`), and no MCP
  server is loaded. Its answer comes back as structured data against
  `tasks/triage_mutants/schema.json`, not as files it writes.
- **It does not see the tests.** `tb/`, `sva/` and `sim/` are unreadable to
  it, so the verdict is about the design, not about what the tests catch.
- **Every answer is checked.** A verdict for exactly the mutants asked about,
  no others; a malformed answer is asked again once, then those mutants are
  left unjudged - and an unjudged mutant counts as plausible.
- **A verdict given before the tests is audited by them.** An equivalent
  mutant can never be killed, so `make mutate TRIAGE=...` simulates the ones
  the agent called equivalent too (`AUDIT=all`, the default) and reports each
  one a test kills as a **triage error**, with the agent's reason beside it.
  A verdict given after the tests is reviewed by the designer.
- **The record is complete.** Each run's folder holds the exact command, every
  prompt sent and every raw response.

## Setting up

Everything the deterministic tools need is already what `sim/` needs. The AI
steps need one more thing, Claude Code, on the machine that runs them.

```
make setup_check            says what is installed and how to get what is not
```

To install Claude Code (Linux, or inside WSL on Windows - not from
PowerShell):

```
curl -fsSL https://claude.ai/install.sh | bash
```

Open a new terminal, then `claude --version` should print a version. Run
`claude` once in the repository and follow the browser prompt to log in with
the subscription account; a Pro plan or higher is needed, and no API key.
`claude doctor` reports on the installation if something is off.

Then, before the first real run, see exactly what would be sent:

```
make judge DRY=1            writes the prompts and the command, calls nothing
```

## How much it uses, and which model

A request carries the task instructions, the list of mutants and whatever
RTL the agent reads - the module's file and the package. Rough sizes,
estimated from the file sizes (not measured from a run):

| | Requests | Input | Output |
|---|---:|---:|---:|
| `make judge`, about 130 survivors | under 10 | about 0.3 million tokens | about 15 thousand |
| `make triage`, every mutant | about 45 | about 1.3 million tokens | about 130 thousand |

On a subscription this counts against the plan's usage limits, not a bill.
If a limit stops a run, `RESUME=` continues it without repeating what is
done.

The judgement is real reasoning about RTL - reachability, invariants - so
use the strongest model the plan gives (`MODEL=`), especially for `make
judge`, where there are few mutants and each verdict matters. A small, fast
model will call more real gaps "equivalent"; that is the costly mistake.

## Layout

| Path | What it holds |
|---|---|
| `tasks/triage_mutants/TASK.md` | the instructions the agent is given |
| `tasks/triage_mutants/schema.json` | the shape its answer must have |
| `scripts/triage_mutants.py` | the runner for both orders: selects the mutants, sends them a module chunk at a time through `claude -p`, checks each answer, writes the verdicts and the run record |
| `scripts/settings_readonly.json` | the permission settings for a read-only task |

A run's record is written to `build/ai_runs/<date>_<time>_<task>/` (not
committed). `make judge_evidence` and `make triage_evidence` also copy it to
`evidence/ai_runs/` and add a row to the ledger there.

## Running it

On the designer's machine, with Claude Code installed and logged in:

```
make judge DRY=1                         write the prompts, call nothing
make judge                               the newest mutation run's survivors
make judge RESULTS=build/mutation/<run>/results.json
make judge RESUME=build/ai_runs/<run>    continue a run a usage limit stopped
make triage MODULE=supervisor            the before-the-tests order, one module
```

`MODEL=` passes a model name to the agent; the models actually used are read
from the responses and written into the run record.

## Planned tasks

| Task | The agent's job | Gate |
|---|---|---|
| `kill_mutants` | write the property or test that kills a surviving mutant | the mutant is killed and the real RTL still passes |
| `expand_checkers` | compare each module's checker against its extracted contract and add what is missing | new properties pass on the RTL and are covered |
| `shadow_model` | write an independent model of a module from its contract alone, for differential testing | differences are explained, and each one is a model error or a design bug |
| `close_coverage` | read the coverage holes and write tests or constraints to reach them | the bins are hit, and no existing test breaks |
| `mine_traces` | judge candidate invariants from `verif_automation/tools/trace_mining` | accepted ones become properties that pass |
