# tools/common

`svparse.py` is the SystemVerilog reader the contract extractor and the
mutation tools share. It is not a full parser: it reads the subset this
project's RTL uses, and raises an error naming the line when it meets
something else, so no tool ever acts on code it misread.

What it gives for each file:

- the text with comments and string contents blanked to spaces, every offset
  unchanged - an edit found on the blanked text applies to the real text as is;
- tokens, each with its text, kind, line and offsets;
- for each module and package: the header fields, the parameters and ports
  with their descriptions, and every procedural block, continuous assign and
  function;
- for each block, a statement tree: `begin` / `end`, `if` / `else`, `case` items,
  loops, and assignments split into target, operator and value.

The linter (`tools/lint/sv_lint.py`) predates it and keeps its own reader.
