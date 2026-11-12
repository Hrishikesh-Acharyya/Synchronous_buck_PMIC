# AI run ledger

One row per run of the agent through `verif_automation/ai/scripts/run_task.sh`, in the
order they ran. A run's full record (the instructions sent, the diff it
produced, the gate output) is in `<date>_<task>/` beside this file.

Columns:

- **Run:** `A1`, `A2`, and so on.
- **Date / commit:** when it ran and on which commit.
- **Task:** the folder in `verif_automation/ai/tasks/`.
- **Given:** the inputs the agent was allowed to read.
- **Produced:** the files it wrote or changed.
- **Gate:** the checks run on its output, and their result.
- **Verdict:** accepted, partly accepted or rejected, and by whom.
- **Findings:** the IDs in `findings.md`.

| Run | Date | Commit | Task | Given | Produced | Gate | Verdict | Findings |
|---|---|---|---|---|---|---|---|---|

No runs yet.
