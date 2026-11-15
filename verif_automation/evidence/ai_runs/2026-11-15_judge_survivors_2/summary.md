# Judgement of surviving mutants - 2026-11-15 - commit a1dc229

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 6; passed lint and sent to triage: 6; judged: 6; judged equivalent with high confidence: 4; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_hiccup_timer | 6 | ok | 4 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `hiccup_timer.99.SDL.1`: Line 99 assigns cool_counter to itself inside an always_ff. Removing it leaves cool_counter unassigned on that path, so the flop keeps its value anyway and nothing changes.
- `hiccup_timer.99.STK.1`: Line 99 only runs in the same branch where line 98 sets hiccup_done to 1, so the first match happens at the same time as before. After that, hiccup_done can only be cleared by reset or !hiccup_active (lines 85 and 91), and both also clear cool_counter (lines 84 and 92). cool_counter is not a port, so the different value it holds until then is never seen, and hiccup_done is the only output.
- `hiccup_timer.99.STK.2`: Line 99 only runs as hiccup_done is set to 1 on line 98, and hiccup_done stays 1 until reset or !hiccup_active, which also clear cool_counter (lines 84 and 92). Setting the internal counter to all-ones in between, or letting it wrap from there, never changes hiccup_done, the only output.
- `hiccup_timer.99.VNG.1`: The inverted counter on line 99 is written only once hiccup_done has been set to 1 (line 98). hiccup_done cannot drop until reset or !hiccup_active (lines 82-92), and those branches also set cool_counter to 0, so the changed counter never reaches the output.

## Judged a real gap - the edit changes behaviour and no test noticed

- `hiccup_timer.56.AIM.1` (high): Moving the cast inside the shift on line 56 can change how wide the shift is evaluated. Depending on the tool's sizing rules, the top bits of base_clks<<strike_level can be lost at HICCUP_BASE_W, which gives a smaller cool_down_target and changes when line 96 matches and hiccup_done rises.
- `hiccup_timer.85.SDL.1` (high): Without line 85, the asynchronous reset no longer clears hiccup_done. At power-up it stays X, and a reset that arrives while it is 1 leaves it at 1, which shows on the output port.
