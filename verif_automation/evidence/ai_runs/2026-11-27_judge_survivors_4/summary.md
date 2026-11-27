# Judgement of surviving mutants - 2026-11-27 - commit 0ee549a

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 12; passed lint and sent to triage: 12; judged: 12; judged equivalent with high confidence: 7; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_supervisor | 12 | ok | 7 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `supervisor.135.SDL.1`: Every branch of the case on lines 137-222, including the default on line 220, assigns next_state. So the default assignment on line 135 is always overwritten before anything reads it.
- `supervisor.148.SDL.1`: This else branch only runs when state == S_OFF (line 139). Line 135 has already set next_state = state = S_OFF, so deleting the redundant assignment changes nothing.
- `supervisor.173.SDL.1`: This branch only runs when state == S_SS (line 154). Line 135 has already set next_state = state = S_SS, so deleting the assignment leaves the same value.
- `supervisor.193.SDL.1`: This branch only runs when state == S_RUN (line 179). Line 135 has already set next_state = S_RUN, so the deleted assignment was redundant.
- `supervisor.213.SDL.1`: This branch only runs when state == S_HICCUP (line 199). Line 135 has already set next_state = S_HICCUP, so the deleted assignment was redundant.
- `supervisor.237.CID.1`: With the S_OFF item deleted, S_OFF falls into the default on line 241, which also assigns en_from_state = 1'b0. The result is identical.
- `supervisor.240.CID.1`: With the S_HICCUP item deleted, S_HICCUP falls into the default on line 241, which also assigns en_from_state = 1'b0. The result is identical.

## Judged a real gap - the edit changes behaviour and no test noticed

- `supervisor.220.ENM.1` (medium): The default branch on line 220 can't be reached: the four enum values cover every 2-bit encoding, and state only ever holds legal values from reset (line 104) or next_state. Its target only matters for an X state in simulation before reset.
- `supervisor.220.SDL.1` (medium): state_t is a 2-bit enum, and S_OFF/S_SS/S_RUN/S_HICCUP use all four codes (pkg lines 310-313). Reset (line 104) and every next_state assignment load legal values, so the default on line 220 never runs once reset has been applied. The only possible difference is how an X state behaves in simulation before the first reset.
- `supervisor.238.CIS.1` (high): Relabelling line 238 as S_RUN leaves S_SS with no item of its own, so S_SS takes the default on line 241 (en_from_state = 0). That forces en low during soft start (line 275), which is visible at the en port.
- `supervisor.241.CST.1` (medium): The default on line 241 can't be reached: S_OFF/S_SS/S_RUN/S_HICCUP use every 2-bit code, and state is always loaded with a legal value (lines 104, 109). Its constant only matters for an X state in simulation before reset.
- `supervisor.241.SDL.1` (medium): Lines 237-240 already cover all four 2-bit state encodings, and state only ever holds legal values after reset, so the default on line 241 never runs. Deleting it only creates an inferred latch that is never exercised. The only difference would be how an X state behaves in simulation before reset.
