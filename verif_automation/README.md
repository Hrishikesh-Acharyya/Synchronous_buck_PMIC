# verif_automation

Verification beyond the handwritten suites in `tb/` and `sva/`: tools that
check or extend that work, an AI agent that writes more of it, and the dated
record of what both found.

| Folder | What it holds |
|---|---|
| `tools/` | deterministic tools, no AI: fixed rules, run from `make`, the same answer every time. Lint now; contract extractor, mutation runner, traceability and trace mining planned |
| `ai/` | AI-assisted verification: the tasks given to an AI agent and the scripts that run it, with the rules it works under (it never edits RTL) |
| `evidence/` | every result from `tools/` and `ai/`, named `<date>_<what>`: lint reports, mutation scores, the AI run ledger and findings, RTL change requests. Empty until the tools are running |

Each folder has its own README.

Commands for this folder are in its own `Makefile` (`make help`), kept apart
from `sim/Makefile`, which runs the verification suites.
