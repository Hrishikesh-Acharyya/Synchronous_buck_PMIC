# Judgement of surviving mutants - 2026-11-15 - commit 05405e5

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 4; passed lint and sent to triage: 4; judged: 4; judged equivalent with high confidence: 0; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_timestamp | 4 | ok | 0 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

None.

## Judged a real gap - the edit changes behaviour and no test noticed

- `timestamp.113.SIB.1` (medium): With the defaults (PRESCALAR_W=16, TIMESTAMP_W=24), TIMESTAMP_W'(49999) equals PRESCALAR_W'(49999), and the 16-bit prescalar is widened with zeros for the compare, so the increment condition on line 113 does not change. Confidence is only medium: with a simulation override where TIMESTAMP_W < $clog2(PRESCALE_VAL+1), the cast cuts off high bits and the tick condition differs.
- `timestamp.62.EDG.1` (high): Line 62 moves the prescaler update to the falling clock edge, while the timestamp_ms block (line 94) still runs on the rising edge. This shifts when line 113 sees the terminal count, so timestamp_ms increments on different clock edges.
- `timestamp.72.SDL.1` (high): Without line 72, reset leaves prescalar uninitialised (X in simulation, an arbitrary value in hardware). In simulation the compares on lines 78 and 113 and the add on line 86 then keep it X, so timestamp_ms never increments correctly; in hardware the first tick comes at a different time.
- `timestamp.78.SIB.1` (medium): With the defaults (PRESCALE_VAL=50000, PRESCALAR_W=16, TIMESTAMP_W=24), casting 49999 to 24 bits instead of 16 gives the same value, and the compare widens the 16-bit prescalar with zeros, so line 78 behaves the same. Confidence is only medium: the header (lines 34-45) says the testbench overrides both parameters, and if TIMESTAMP_W < PRESCALAR_W the cast cuts off high bits and changes the terminal count.
