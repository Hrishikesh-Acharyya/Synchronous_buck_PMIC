# Mutation operators

Each mutant is one of these edits, made at one place in one RTL file. The
places come from the statement tree (`tools/common/svparse.py`), not from a
text search.

| ID | Edit | Example |
|---|---|---|
| ROR | relational boundary or equality: `<` and `<=`, `>` and `>=`, `==` and `!=` swapped | `if (count < target)` -> `if (count <= target)` |
| LCR | logical connective: `&&` and `\|\|`, binary `&` and `\|` swapped | `a && b` -> `a \|\| b` |
| AOR | arithmetic: binary `+` and `-` swapped | `count + 1` -> `count - 1` |
| SHF | shift direction swapped | `x << 1` -> `x >> 1` |
| CND | an `if` condition negated | `if (a && b)` -> `if (!(a && b))` |
| UOD | a unary negation dropped | `if (!rst_n)` -> `if (rst_n)` |
| TRN | the branches of a `?:` swapped | `c ? a : b` -> `c ? b : a` |
| CST | a constant changed: `1'b0` and `1'b1`, `'0` and `'1` swapped; any other integer literal plus one and minus one, in its own base and width | `8'd5` -> `8'd6`, `8'd4` |
| ENM | an enum constant replaced by the next member of its enum | `next_state = S_SS` -> `next_state = S_RUN` |
| CCS | the first two elements of a concatenation swapped | `{rx_shift, sdio_in}` -> `{sdio_in, rx_shift}` |
| SDL | one procedural assignment statement deleted | `count <= count + 1;` -> `;` |
| EDL | an `else` branch deleted | `if (a) ... else begin x = 0; y = 0; end` -> `if (a) ...` |
| ICS | wrong wire: two same-type inputs of one instance swapped, or the same input of two instances of one module swapped | `u_otp_sync (.async_in(OTP_trig))` -> `(.async_in(UVLO_trig))` |

## Where they apply

- Mutated: every `always`, `always_ff`, `always_comb` block, every
  continuous `assign`, every function body and every module instance, in
  every module.
- Not mutated:
  - the package - its constants are design parameters, not logic;
  - `initial` blocks and `generate` regions - in this RTL they are
    elaboration-time checks;
  - declarations, widths and bit selects;
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
  that assignment is the same mutant.

## Outcomes

| Outcome | Meaning | Counts toward the score |
|---|---|---|
| killed | the testbench or a bound checker failed | yes |
| lint | Verilator `-Wall` refused the mutant: `make lint`, run first on every mutant, or the testbench build | yes |
| timeout | the run did not finish in time | yes |
| survived | everything passed: a verification gap, or a mutant that changes nothing (an equivalent mutant) | no |
| stillborn | not a legal design: a hard compile error | left out |

Score = (killed + lint + timeout) / (mutants - stillborn). Whether a survivor
is a gap or an equivalent mutant is not decided by this tool.

## Checking the generator itself

`make mutants_check` screens every mutant with `make lint` and simulates
none: about a minute for all of them. `stillborn` must read 0 - a mutant that
is not legal code is a fault in the generator, not in the design.
