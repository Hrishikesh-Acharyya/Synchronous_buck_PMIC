# RTL change requests

RTL in `rtl-systemverilog/` and `rtl-verilog/` is changed only by the
designer. A tool or an agent run that finds a reason to change it records a
request here, and the designer decides. A request is never deleted; it is
closed with its decision.

Status: `proposed`, `accepted`, `rejected` or `done` (with the commit).

| ID | Date | Raised by | Files | Request | Why | Status |
|---|---|---|---|---|---|---|
| R1 | 2026-11-12 | `sv_lint` (`lint/2026-11-12_lint.txt`) | all RTL modules | Style only: blank lines after begin and before end (S2/S3, 176), begin / end on multi-line if / else (S1, 28), module body indentation (S4, 13), Purpose comments on 9 blocks (C1), `` `default_nettype wire `` at the end of `fault_cause.sv` (H3) | Brings the RTL in line with the coding standard. No behaviour change; checked with the unit testbenches, `equiv_all` and the sv2v conversion afterwards | proposed |
