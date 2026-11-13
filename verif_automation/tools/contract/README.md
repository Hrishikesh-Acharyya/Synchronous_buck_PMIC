# tools/contract

`extract_contract.py` turns each RTL module's contract - what it promises at
its boundary - into a form a tool or an agent task can read.

The contract of a module is its file header (File Description, Global
variables), its parameters (type, default, description) and its ports
(direction, type, width, description). The contract of the package is its
constants and the signatures and Purpose text of its functions.

**Nothing from a module's body is included** - no logic, no internal signals,
no Purpose blocks of its always blocks. A checker or model written from the
contract therefore cannot copy the design's own mistakes.

A description comes from the comment that belongs to the declaration: the one
trailing it on its line, or the comment lines directly above it. A comment
written above a group of declarations applies to the whole group, unless it
names one declaration (`addr: 7 bit address`). Section banners
(`// =====`) are not descriptions.

## Output

`make contract` (from `verif_automation/`) writes to `build/contract/`, which is
not committed:

| File | What it holds |
|---|---|
| `<unit>.json` | the contract, machine-readable, with the date and commit it was taken at |
| `<unit>.md` | the same as a page |
| `index.md` | every unit, its parameter and port counts, and its gaps |

A gap is a port or parameter with no description (`clk` and `rst_n` are not
counted): part of the contract nobody wrote down.
