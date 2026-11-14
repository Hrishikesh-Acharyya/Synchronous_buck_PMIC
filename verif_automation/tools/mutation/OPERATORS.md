# Mutation operators

Each mutant is one of these edits, made at one place in one RTL file. The
places come from the statement tree (`tools/common/svparse.py`), not from a
text search.

| ID | Edit | Example |
|---|---|---|
| ROR | relational boundary or equality: `<` and `<=`, `>` and `>=`, `==` and `!=` swapped | `if (count < target)` -> `if (count <= target)` |
| LCR | logical connective: `&&` and `\|\|`, binary `&` and `\|` swapped; binary `^` to `\|` | `a && b` -> `a \|\| b` |
| CTD | a term dropped from a condition - a missing guard. Each term of an `&&`, `\|\|`, `&` or `\|` chain is dropped once | `if (a && b)` -> `if (a)`, and -> `if (b)` |
| AOR | arithmetic: binary `+` and `-` swapped | `count + 1` -> `count - 1` |
| SHF | shift direction swapped | `x << 1` -> `x >> 1` |
| CND | an `if` condition negated | `if (a && b)` -> `if (!(a && b))` |
| UOD | a unary negation dropped | `if (!rst_n)` -> `if (rst_n)` |
| TRN | the branches of a `?:` swapped | `c ? a : b` -> `c ? b : a` |
| CST | a constant changed: `1'b0` and `1'b1`, `'0` and `'1` swapped; any other integer literal plus one and minus one, in its own base and width | `8'd5` -> `8'd6`, `8'd4` |
| ENM | an enum constant replaced by the next member of its enum | `next_state = S_SS` -> `next_state = S_RUN` |
| DLY | a signal swapped with its one-clock-delayed copy (`x` and `x_d`) - used a clock early or late | `pwm_fall = pwm_sync_d & ~pwm_sync` -> `pwm_sync_d & ~pwm_sync_d` |
| BSL | wrong bit or field: a constant select moved by one, both ways | `x[3]` -> `x[4]`, `x[2]`; `x[15:8]` -> `x[16:9]`, `x[14:7]` |
| CIS | the labels of two adjacent `case` items swapped - a wrong decode | `S_SS: ... S_RUN: ...` -> `S_RUN: ... S_SS: ...` |
| CCS | the first two elements of a concatenation swapped | `{rx_shift, sdio_in}` -> `{sdio_in, rx_shift}` |
| SDL | one procedural assignment statement deleted | `count <= count + 1;` -> `;` |
| EDL | an `else` branch deleted | `if (a) ... else begin x = 0; y = 0; end` -> `if (a) ...` |
| ICS | wrong wire: two same-type inputs of one instance swapped, or the same input of two instances of one module swapped | `u_otp_sync (.async_in(OTP_trig))` -> `(.async_in(UVLO_trig))` |

## Where they apply

- Mutated: every `always`, `always_ff`, `always_comb` block, every
  continuous `assign`, every function body and every module instance - its
  connections (ICS) and the expressions of its parameter overrides
  (`#(.RESET_VALUE(1'b1))` -> `1'b0`) - in every module; and the functions of
  the package (`ns_to_clks` and the like), tested by the integration
  testbench.
- Not mutated:
  - the package's constants - design parameters, not logic;
  - `initial` blocks and `generate` regions - in this RTL they are
    elaboration-time checks;
  - declarations and their widths (a constant select in an expression is
    mutated, by BSL);
  - the width in front of a cast (`8'(x)`) and replication counts;
  - system-task calls such as `$display`.
- In an expression, an operator is only treated as binary (`&`, `|`, `+`, `-`)
  when an operand stands on its left, so a reduction `&x` or a negation `-x`
  is never swapped.
- A `<=` that assigns is never treated as a comparison: assignments are split
  into target, operator and value before any expression is searched.
- A continuous `assign` is never deleted: what is left is not legal code. Its
  expression is still mutated.
- ICS never swaps `clk` or `rst_n`, and never ties an input off: a
  disconnected net is unused, which lint reports at once. A swap keeps both
  nets in use, so only a test can catch it.

## Mutants that are not made

Two mutants that mean the same thing would count one weakness twice, so only
one is made:

- negating a condition that is a single `==` / `!=` comparison - ROR's swap is
  the same mutant;
- negating a condition that is a single negated operand (`if (!x)`) - UOD's
  drop is the same mutant;
- deleting an `else` that holds exactly one assignment - SDL's deletion of
  that assignment is the same mutant;
- DLY on the line that makes the delayed copy (`x_d <= x` -> `x_d <= x_d`) -
  it holds the value, which is SDL's mutant.

One operator was tried and withdrawn: dropping the asynchronous reset from a
flop's sensitivity list. `make lint` (SYNCASYNCNET) rejects every one of the
46, so it could never reach a test and would only pad the score.

## Where the operators came from

The first seven are the standard set. CTD, DLY, BSL, the package functions
and the parameter overrides were added from bugs this project actually had:
a guard term in `reg_file`'s write-reject rule, a checker reading its guard
one clock late, `ns_to_clks` rounding down instead of up, a synchroniser's
reset level, and `reg_file`'s byte and dirty-bit fields. ICS came from
finding that `pmic_top` - 31 instances - had no mutant on any wire.

## Outcomes

| Outcome | Meaning | Counts toward the score |
|---|---|---|
| killed | the testbench or a bound checker failed | yes |
| lint | Verilator `-Wall` refused the mutant: `make lint`, run first on every mutant, or the testbench build | yes |
| covers | every check passed, but an SVA cover the unmutated run hits was not hit: the regression would read INCONCLUSIVE instead of PASS. Caught, but only by a lost cover - listed on its own in the report | yes |
| timeout | the run did not finish in time | yes |
| survived | everything passed: a verification gap, or a mutant that changes nothing (an equivalent mutant) | no |
| stillborn | not a legal design: a hard compile error | left out |

Score = (killed + lint + covers + timeout) / (mutants - stillborn). Whether a
survivor is a gap or an equivalent mutant is not decided by this tool.

## Checking the generator itself

`make mutants_check` screens every mutant with `make lint` and simulates
none: about a minute for all of them. `stillborn` must read 0 - a mutant that
is not legal code is a fault in the generator, not in the design.
