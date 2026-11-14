# Task: write mutants

You are helping with mutation testing of a hardware design written in
SystemVerilog. A mutant is the design with one small fault put into it on
purpose. Each mutant is then simulated against the module's testbench: if the
testbench still passes, the behaviour that fault broke is not being checked.

A program already makes the mechanical mutants - one operator swapped, one
constant changed, one statement deleted (the list is below). It cannot make a
fault that needs an understanding of what the module is for. Those are yours
to write.

## What you are given

- This file.
- The name of **one module** and its file, and how many mutants are asked
  for.
- The mechanical operators, so that you do not repeat them.
- The mutants already written for this module, and the proposals a program
  has already refused (with the check each failed), so that you do not repeat
  those either.
- Read access to the RTL in `rtl-systemverilog/` and to the project's
  documents. Read the module's own file in full first - its header states
  what it must do, and every block has a Purpose comment. Read
  `pkg/pmic_types_pkg.sv` for constants and types, and the modules that
  drive or read this one when a fault's effect depends on them.

You cannot edit files, run commands or simulations, or reach the network, and
you do not need to: you return the mutants as data, and a program checks and
stores them. The testbenches and checkers are deliberately not readable. A
mutant is a fault a designer could have made, written from the design alone -
not one aimed at what the tests happen to miss.

## What a good mutant is

A fault that:

1. **a designer could really have made** while writing or changing this
   module - a rule misremembered, one case forgotten, an event confused with
   a similar one;
2. **changes what the module does at its ports**, in some state it can
   reach, for some input sequence its header allows - say which, in `reason`;
3. **needs the design's meaning to write**. If one mechanical operator on
   one token makes the same fault, do not write it;
4. is still **legal code that lint accepts**: every signal still driven and
   still used, no width changed, no latch made.

Kinds of fault to look for - use these as `category`:

| Category | The fault |
|---|---|
| `wrong_event` | something is captured, counted or cleared on the wrong event, or in the wrong state: a snapshot taken at the end of a transaction instead of its start, a counter cleared on entry instead of exit |
| `missing_case` | a rule that forgets one state, one address, one mode or one source: a write-reject rule that lets one register through, a fault source left out of a summary bit |
| `priority` | two conditions answered in the wrong order: an `if` / `else if` chain reordered, a later assignment that should lose winning |
| `boundary` | a limit wrong for one case only: saturating one count early, wrapping instead of saturating, a threshold compared with the wrong one of two limits |
| `protocol` | the serial interface's framing: bit order, which clock phase a bit is taken on, the bit or byte count that ends a field, what an aborted transaction leaves behind |
| `field` | a register's contents mapped wrongly: bytes of a multi-byte value in the wrong order, a field read from the live value instead of the snapshot, a read-only bit made writable |
| `sequencing` | right value, wrong clock: a flag raised one clock early or late, a stale value used, a handshake that does not wait |
| `reset_init` | state that is not put back: a register missing from one of several clear conditions, a value that survives a re-entry it should not |
| `other` | a design-aware fault that fits none of these |

## What not to write

- An edit that only changes a comment, spacing or a name.
- An edit to the module's ports, its header parameters, or the width of any
  declaration.
- An edit that leaves a signal undriven or unused, or assigns a signal from
  two blocks - lint rejects those before any test runs. Lint also rejects a
  flop whose asynchronous reset is made synchronous, or dropped from its
  sensitivity list.
- An edit that one mechanical operator already makes.
- Two mutants that are the same fault written twice.
- A fault that cannot change anything at the ports. If you cannot say what
  changes and when, leave it out.

## The form of a mutant

One mutant is **one edit to one place**: some consecutive whole lines of the
file replaced by other lines.

- `line` - the number of the first line you replace, as the Read tool shows
  it.
- `before` - those lines, copied exactly from the file, one string per line,
  in order. Whole lines. At most 12.
- `after` - the lines that take their place. At most 16. Keep the house
  layout: `begin` / `end` on every block, the same indentation as the lines
  around it.
- Change as little as the fault needs: at most 6 lines may differ between
  `before` and `after`. Lines you include only for context must be identical
  in both.
- `description` - one line saying what the fault is, in the design's terms:
  "FCOUNT_RUN is cleared by a write to FCOUNT_SS", not "changed line 512".
- `reason` - one or two sentences: which behaviour at the ports changes, and
  in which situation.

## Rules

1. Write the number of mutants asked for if the module has that many
   distinct design-aware faults in it. A small module may not: fewer good
   mutants are better than the number made up with weak ones.
2. Spread them over the module - every block that holds a decision, not
   five variations on one line.
3. Each mutant stands alone: it is applied to the unmodified file, never on
   top of another.
4. Judge the module with the parameter values this design uses (the defaults
   in its header and the package).
5. Do not explain or summarise outside the structured answer.
