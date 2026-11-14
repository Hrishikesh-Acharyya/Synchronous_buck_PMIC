# verif_automation/ai

AI-assisted verification: an AI agent writes and judges verification work,
and the simulator decides whether that work holds. This folder holds
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
   cannot copy the design's own mistakes. When it works on the design itself -
   writing mutants, judging mutants - it reads the RTL and is kept away from
   the testbenches and checkers, so its work is about the design and not
   about what the tests happen to catch.
5. **Everything is disclosed.** Every run is logged: what it was asked, what
   it was given, what it produced, what checks ran, what was accepted or
   rejected and why, and the agent's own mistakes. A rejected or wrong output
   is logged the same as an accepted one.

## The tasks, in the order they are used

| Step | Command | Who does it |
|---|---|---|
| 1. write the design-aware mutants | `make ai_mutants` | the agent proposes; a deterministic gate decides what is kept |
| 2. check every mutant is legal code | `make mutants_check` | the tools, no AI |
| 3. simulate every mutant | `make mutate` | the tools, no AI |
| 4. judge the survivors | `make judge` | the agent gives a first opinion |
| 5. decide each survivor | `make decide` | the designer |

Nothing in steps 1 or 4 writes a checker or a test, and nothing the agent
says changes a score: the score comes from step 3 alone.

Every step is run a module at a time (`MODULE=`) and added to that module's
record, `evidence/mutation/<module>.json` and `.md` - the mutants the agent
wrote and the proposals the gate rejected, each mutant's outcome in every
run, each judgement, each decision. Running a step again adds to the record;
nothing in it is replaced (`../tools/mutation/README.md`).

## Writing mutants

A mutant is the design with one small fault put in on purpose
(`tools/mutation`). The mechanical operators make the faults that are one
token wide - a `<` for a `<=`, a constant off by one, a line deleted - 3,274
of them. What they cannot make is a fault that needs to know what the module
is for:

- a snapshot taken at the end of a transaction instead of its start;
- a write-reject rule that lets one register through;
- a count that saturates one early in one mode only;
- an aborted SPI transaction that leaves a half-written byte behind.

Those are the agent's to write (`tasks/write_mutants/TASK.md`). It reads one
module at a time and returns faults as data: the lines to replace, the lines
to put there, what the fault is, and what changes at the ports. Most are
asked for where the design-aware faults are - 40 for `reg_file`, 30 for
`spi_slave`, 15 for `pmic_top`, 12 for `supervisor`, 6 for each small module
(`COUNT=` changes that). At most 20 are asked for in one request; a module
asked for more gets several, each shown what the earlier ones produced.
Running it again for a module adds to what is there in the same way: the
agent is shown the mutants already written and asked for different ones. It is also shown every proposal the gate has already refused
for the module, with the check it failed, so a second run does not spend
itself on the same refused idea.

The agent only proposes. `scripts/write_mutants.py` puts every proposal
through a gate, and stores only what passes:

1. the lines it replaces are in the file, at one place;
2. it changes at most 6 lines, inside the module's body - not its ports or
   parameters;
3. it changes the code, not only comments or spacing;
4. it is not a mutant a mechanical operator already makes, nor one already
   stored;
5. it is legal code and `make lint` accepts it - so only a test can catch it.

What passes is added to `mutants/<module>.json`. From there `make mutate`
runs it beside the mechanical mutants, as operator `AIM`: the same lint
screen, the same testbench, the same score. Every rejected proposal is
listed in the run record with the check it failed.

What the gate does not decide is whether a mutant is a *good* one - a fault
worth testing for. The stored files are plain JSON, a dozen lines a mutant:
read them, delete any entry that is not a fault a designer could make, and
commit the rest. Once committed, the set is fixed - a mutation run uses the
file, never the agent, so it gives the same result every time.

```
make ai_mutants DRY=1                  write the prompts, call nothing
make ai_mutants MODULE=reg_file        one module
make ai_mutants                        every module
make mutants OPERATORS=AIM             list what is stored
make mutants_check OPERATORS=AIM       lint-screen them again (after an RTL change)
make mutate OPERATORS=AIM              simulate only them
```

A stored mutant is found by the text of the lines it replaces, so it follows
those lines when the file above them changes. If the lines themselves change,
it can no longer be placed: `make mutants` and the mutation report name it as
left out, and it needs writing again.

## Judging mutants

The agent's job here is one question per mutant, answered from the RTL
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
make mutate MODULE=m        simulate the module's mutants - no AI
make judge MODULE=m         the agent judges its undecided survivors
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
several times the requests (roughly 2,800 mutants pass lint, against a few
hundred survivors).

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
  A verdict given after the tests is an opinion in the module's record; the
  designer's decision is recorded beside it (`make decide`).
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
the subscription account; a Pro plan or higher is needed, and no API key
(`echo $ANTHROPIC_API_KEY` should print nothing - with a key set, requests
are billed to it instead of the plan). `claude doctor` reports on the
installation if something is off.

If `claude` stops with "Unable to connect to Anthropic services", the machine
cannot reach `api.anthropic.com` or `platform.claude.com`. Test from the same
terminal with `curl -I https://api.anthropic.com`; under WSL the usual causes
are a VPN, a proxy that needs `HTTPS_PROXY` set, or a DNS server in
`/etc/resolv.conf` that does not answer.

Then check that the agent is ready for these tasks:

```
make ai_check
```

It sends one small request with the same command and permission settings as
the real tasks, and checks that the answer comes back in the tasks' form,
that the RTL can be read, and that the testbenches can be neither opened nor
searched. Every line should read `ok`.

Before the first real run, see exactly what would be sent:

```
make ai_mutants DRY=1       writes the prompts and the command, calls nothing
make judge DRY=1
```

## How much it uses, and which model

A request carries the task instructions, the list of mutants and whatever
RTL the agent reads - the module's file and the package. Rough sizes: the
first row is scaled from two trial requests made while the script was built,
their output discarded (4 mutants for `hiccup_timer`:
29 thousand tokens in, 3 thousand out, 40 seconds; 12 for `reg_file`: 45
thousand in, 12 thousand out, two minutes); the other two are estimated from
the file sizes, not measured:

| | Requests | Input | Output |
|---|---:|---:|---:|
| `make ai_mutants`, every module | about 20 | about 0.7 million tokens | about 0.2 million |
| `make judge`, a few hundred survivors | 10 to 20 | about 0.6 million tokens | about 30 thousand |
| `make triage`, every mutant | about 80 | about 2.5 million tokens | about 250 thousand |

On a subscription this counts against the plan's usage limits, not a bill.
If a limit stops `make judge` or `make triage`, `RESUME=` continues it without
repeating what is done. `make ai_mutants` stores each module's mutants as it
goes; after a stop, run it again with `MODULE=` naming the modules left.

Every AI step runs on the model and reasoning effort set by `MODEL=` and
`EFFORT=`. The default is `MODEL=opus EFFORT=medium`. Both are passed to the
agent as given: a model alias (`opus`, `sonnet`, `fable`), and `low`,
`medium`, `high`, `xhigh` or `max`. The model each run really used is read
from its responses and written into the module's record.

One trial request per model, six mutants for `strike_counter` at medium
effort, output discarded:

| Model | Accepted by the gate | Then killed by a named assertion | Tokens in / out | Time |
|---|---:|---:|---:|---:|
| `opus` | 4 of 6 | 4 of 4 | 21 thousand / 3 thousand | 35 s |
| `sonnet` | 6 of 6 | 5 of 6, one survived | 36 thousand / 4 thousand | 28 s |

Both wrote faults that need the design's meaning, and `sonnet` counts for
less against a plan's limits - so `MODEL=sonnet` is the economical choice
for the small modules. That is one small module: for `reg_file`, `spi_slave`,
`pmic_top` and `supervisor`, and for `make judge` - where calling a real gap
"equivalent" is the costly mistake - keep the default or raise the effort
(`EFFORT=high`).

## Layout

| Path | What it holds |
|---|---|
| `tasks/write_mutants/TASK.md` | the instructions for writing mutants |
| `tasks/write_mutants/schema.json` | the shape of a proposed mutant |
| `scripts/write_mutants.py` | asks for mutants a module at a time through `claude -p`, gates every proposal, stores what passes, writes the run record |
| `mutants/<module>.json` | the accepted AI-written mutants - committed, and what `make mutate` runs |
| `tasks/check_agent/` | the small request `make ai_check` sends |
| `scripts/check_agent.py` | the readiness check |
| `tasks/triage_mutants/TASK.md` | the instructions for judging mutants |
| `tasks/triage_mutants/schema.json` | the shape its answer must have |
| `scripts/triage_mutants.py` | the runner for both orders: selects the mutants, sends them a module chunk at a time through `claude -p`, checks each answer, writes the verdicts and the run record |
| `scripts/settings_readonly.json` | the permission settings for a read-only task |

A run's record is written to `build/ai_runs/<date>_<time>_<task>/`. Every
real run is also kept as evidence: its record is copied to
`evidence/ai_runs/`, a row is added to the ledger there, and what it produced
is added to the module records in `evidence/mutation/`. `RECORD=0` leaves a
run out of all three - for trying the tools.

## Running it

On the designer's machine, with Claude Code installed and logged in:

```
make ai_mutants                          write and gate the design-aware mutants
make mutants_check                       every mutant, mechanical and AI-written, is legal
make mutate                              simulate them all - no AI
make judge DRY=1                         write the prompts, call nothing
make judge MODULE=supervisor             the module's undecided survivors
make judge RESUME=build/ai_runs/<run>    continue a run a usage limit stopped
make decide IDS=<id> AS=equivalent WHY="the reason"
make triage MODULE=supervisor            the before-the-tests order, one module
```

`MODEL=` and `EFFORT=` set the agent's model and reasoning effort (default
`opus`, `medium`); the models actually used are read from the responses and
written into the run record.

## Planned tasks

| Task | The agent's job | Gate |
|---|---|---|
| `kill_mutants` | write the property or test that kills a surviving mutant | the mutant is killed and the real RTL still passes |
| `expand_checkers` | compare each module's checker against its extracted contract and add what is missing | new properties pass on the RTL and are covered |
| `shadow_model` | write an independent model of a module from its contract alone, for differential testing | differences are explained, and each one is a model error or a design bug |
| `close_coverage` | read the coverage holes and write tests or constraints to reach them | the bins are hit, and no existing test breaks |
| `mine_traces` | judge candidate invariants from `verif_automation/tools/trace_mining` | accepted ones become properties that pass |
