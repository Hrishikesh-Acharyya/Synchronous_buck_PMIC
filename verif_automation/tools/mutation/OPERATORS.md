# Mutation operators

Each mutant is one of these edits, made at one place in one RTL file. The
places come from the statement tree (`tools/common/svparse.py`), not from a
text search.

| ID | Edit | Example |
|---|---|---|
| ROR | relational boundary or equality: `<` and `<=`, `>` and `>=`, `==` and `!=` swapped | `if (count < target)` -> `if (count <= target)` |
| LCR | logical connective: `&&` and `\|\|`, binary `&` and `\|` swapped | `a && b` -> `a \|\| b` |
| AOR | arithmetic: binary `+` and `-` swapped | `count + 1` -> `count - 1` |
| CND | an `if` condition negated | `if (!rst_n)` -> `if (!(!rst_n))` |
| CST | a constant changed: `1'b0` and `1'b1`, `'0` and `'1` swapped; any other integer literal plus one and minus one, in its own base and width | `8'd5` -> `8'd6`, `8'd4` |
| SDL | one assignment statement deleted | `count <= count + 1;` -> `;` |
| EDL | an `else` branch deleted | `if (a) x = 1; else x = 0;` -> `if (a) x = 1;` |

## Where they apply

- Mutated: every `always`, `always_ff`, `always_comb` block, every
  continuous `assign`, and every function body, in every module.
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

## Outcomes

| Outcome | Meaning | Counts toward the score |
|---|---|---|
| killed | the testbench or a bound checker failed | yes |
| lint | Verilator `-Wall` refused the mutant (the testbench build runs with `-Wall`, as `make lint` does) | yes |
| timeout | the run did not finish in time | yes |
| survived | everything passed: a verification gap, or a mutant that changes nothing (an equivalent mutant) | no |
| stillborn | not a legal design: a hard compile error | left out |

Score = (killed + lint + timeout) / (mutants - stillborn). Whether a survivor
is a gap or an equivalent mutant is not decided by this tool.
