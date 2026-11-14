# Task: triage mutants

You are helping with mutation testing of a hardware design written in
SystemVerilog. A mutant is the design with one small edit made to one line.
Before any mutant is simulated, you sort them: which edits can change what
the module does, and which cannot.

## What you are given

- This file.
- A list of mutants of **one module**, as JSON: for each, its `id`, the
  `line` it is on, the `operator` that made it, a `description`, and the line
  `before` and `after` the edit.
- Read access to the RTL in `rtl-systemverilog/`. Read the module's own file
  in full before judging anything. Read `pkg/pmic_types_pkg.sv` for constants
  and types. You may read other RTL files when a mutant's meaning depends on
  them.

You cannot edit files, run commands or simulations, or reach the network, and
you do not need to. The testbenches and checkers are deliberately not
readable: your judgement is about the design, not about what the tests would
catch.

## The question, for each mutant

Can this edit change the module's behaviour as seen at its **ports** - any
output, on any clock edge, in any state the module can reach, for any input
sequence the module's header does not rule out?

- **`plausible`** - yes, or you are not certain it cannot. This is the
  default. Every plausible mutant will be simulated.
- **`equivalent`** - no. The edit changes nothing that can be observed. Use
  this only when you can give the specific argument, for example:
  - the edited code can never execute (say which condition is never true, and
    why);
  - the edited value is never used, or is overwritten before anything reads
    it;
  - the two forms are the same under an invariant of the module (state the
    invariant and the lines that establish it).

## Rules

1. **When in doubt, `plausible`.** Calling a real behaviour change
   "equivalent" hides a possible gap in the verification; calling an
   equivalent mutant "plausible" only costs a simulation. The first mistake
   is much worse than the second.
2. Judge the module **as written, with the parameter values this design
   uses** (the defaults in its header and the package). Do not assume
   anything about the inputs beyond what the module's header states.
3. An edit to a reset value, a counter bound, a comparison or a state
   transition is almost always plausible. Do not argue such a mutant away
   with "this case is unlikely" - unlikely is still reachable.
4. `confidence` is how sure you are of the verdict: `high` only if you could
   defend the argument line by line; otherwise `medium` or `low`. Only an
   `equivalent` verdict with `high` confidence keeps a mutant out of
   simulation - and those are audited by simulating them anyway.
5. `reason` is one or two sentences, specific to this mutant, naming line
   numbers. Not "this is a standard mutation".
6. Give exactly one verdict for every `id` in the list, and no others.

## Output

Return only the structured result: a `verdicts` array, one object per mutant,
with `id`, `verdict`, `confidence` and `reason`.
