# RTL change requests

RTL in `rtl-systemverilog/` and `rtl-verilog/` is changed only by the
designer, or with the designer's approval. A tool or an agent run that finds a
reason to change it records a request here. A request is never deleted; it is
closed with its decision. Layout-only changes made under the lint rules are
not requests: they leave the sv2v output token-identical.

| ID | Date | Raised by | Files | Request | Why | Status |
|---|---|---|---|---|---|---|
| R1 | 2026-11-13 | lint clean-up (T1 exposed it; see `lint/README.md`) | `inputs/input_debounce.sv`, `.v` | Clear `disagree_counter` on the edge `flag_out` flips. | A reversal of `flag_in` on the clock after a flip inherited the old count, so the next transition qualified early. | done, 59a6fef - approved by the designer, with the checker and testbench changes that go with it |
