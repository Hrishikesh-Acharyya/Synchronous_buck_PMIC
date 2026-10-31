# Changelog - Silicluster v3 submission branch

Every change made on this branch, newest at the bottom, with a UTC timestamp,
the files touched, why, and how to undo it. `main` is never touched.

Branch: the Silicluster v3 submission branch, cut from `main` at `a70e4a9`.

## How to undo a change

Each entry is exactly one commit. To back one out without disturbing the
others:

```bash
git revert <commit>
```

Then rerun the gate (`cd sim && make lint && make -B convert && make -j4 equiv_all`)
because the RTL entries regenerate `Build/pmic_full.v`, and a revert of an RTL
commit restores the previous converted file along with it. Entries that depend
on an earlier one say so - revert the later one first.

The commit hash of each entry is listed in the table at the end. A commit
cannot contain its own hash, so the table is filled in by a later commit.

---

## 1. 2026-10-31 17:13 UTC - docs: start the changelog and the area log

- Files: `docs/CHANGELOG_silicluster_v3.md` (new), `docs/silicluster_area.md` (new)
- What: this file, and the append-only area log required by the project rules, section 7,
  seeded with a measured baseline of `main` at 50 MHz.
- Why: the user asked for a changelog that makes every change undoable; the area
  log is part of the Silicluster deliverable.
- Finding recorded: the baseline mapped area (32,369 um^2 cell area, 2,281
  combinational cells) is materially lower than the reference in the project rules
  (~43,000 um^2, 3,039 cells). The reference appears to have used the generic
  gate count. Flop count (730) agrees exactly.
- Undo: `git revert <hash>` (documentation only, no functional effect).
