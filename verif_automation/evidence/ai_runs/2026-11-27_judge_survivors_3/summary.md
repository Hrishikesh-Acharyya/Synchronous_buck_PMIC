# Judgement of surviving mutants - 2026-11-27 - commit 13c1372

Agent: Claude Code (claude -p), read-only; model(s): claude-opus-5-5
Mutants listed: 34; passed lint and sent to triage: 34; judged: 34; judged equivalent with high confidence: 5; untriaged: 0

| Chunk | Mutants | Outcome | Note |
|---|---:|---|---|
| 001_fault_arbiter | 34 | ok | 5 judged equivalent (high confidence) |

## Judged equivalent (high confidence)

- `fault_arbiter.215.SIB.1`: The 1-bit operand is zero-extended to 5 bits instead of 6, but the context width set by the 6-bit fault_count_ss and LHS makes the value identical.
- `fault_arbiter.216.SIB.1`: The unsigned 1-bit subtrahend is cast to 5 bits instead of 6, then extended to the 6-bit context width of line 215, so the result is the same.
- `fault_arbiter.217.SIB.1`: The 1-bit value is cast to 16 bits instead of 32 and zero-extended to the 32-bit OR context, so fault_shifter_SS gets the same value.
- `fault_arbiter.60.CST.2`: With WINDOW_RUN=16, $clog2(17)=5 and $clog2(18)=5, so FCNT_RUN_W on line 60 is unchanged and nothing downstream changes.
- `fault_arbiter.61.CST.2`: With WINDOW_SS=32, $clog2(33)=6 and $clog2(34)=6, so FCNT_SS_W on line 61 is unchanged.

## Judged a real gap - the edit changes behaviour and no test noticed

- `fault_arbiter.144.CSK.1` (high): cp_delay is not cleared at reset (line 146 is skipped), so it can start as X or hold history shifted in while run_active was high during reset. A sample taken soon after reset then reads a different value.
- `fault_arbiter.146.CST.1` (high): Resetting cp_delay to all ones means that a pwm_rise within BLANK_CLKS clocks after reset, while active, records a faulted cycle where the original records 0.
- `fault_arbiter.146.SDL.1` (high): Without the reset clear, cp_delay holds X or a stale value through reset. If the module is active straight after reset, an early pwm_rise samples it and gives a different count.
- `fault_arbiter.150.AIM.97` (high): Clearing cp_delay on every falling PWM edge zeroes the history whenever the low-side period is shorter than BLANK_CLKS. cp_delay[4] at pwm_rise then reads 0 where the original reads cp_sync.
- `fault_arbiter.152.SDL.1` (high): Without the idle clear, cp_delay keeps comparator history from before the idle period. A pwm_rise within 5 clocks of re-entering S_SS/S_RUN samples that stale bit instead of 0.
- `fault_arbiter.156.AIM.43` (high): Freezing cp_delay while pwm_sync is high changes which cp_sync clock cp_delay[4] holds at pwm_rise, so the recorded sample can differ.
- `fault_arbiter.158.AIM.81` (high): If PWM was high at the clock that ends up in cp_delay[4] at pwm_rise (low period under 5 clocks), the mutant records 0 where the original records cp_sync=1.
- `fault_arbiter.195.BDL.1` (high): With an empty reset body, the counts and windows are never reset, so the count outputs show X or hold values during reset.
- `fault_arbiter.195.CSK.1` (high): With no reset branch, the counts and shift registers are never initialised, and the telemetry outputs show X during reset.
- `fault_arbiter.197.AIM.117` (high): The shift registers are not reset, so they start as X. If run_active or ss_active is high right after reset, the idle clear never runs, and the subtract of the leaving bit at line 207/216 brings X or stale bits into the counts.
- `fault_arbiter.197.CST.1` (high): Resetting fault_shifter_RUN to 1 puts a phantom fault bit in the window. If S_RUN is entered directly after reset, it leaves after 16 rises and decrements (underflows) fault_count_run.
- `fault_arbiter.197.SDL.1` (high): fault_shifter_RUN stays uninitialised after reset. If run_active is high straight away, the bit leaving at line 207 is X or stale and corrupts fault_count_run.
- `fault_arbiter.198.CST.1` (high): Resetting fault_shifter_SS to 1 puts a phantom bit in the window. If S_SS is entered directly after reset, it is subtracted after 32 rises and fault_count_ss underflows.
- `fault_arbiter.198.SDL.1` (high): fault_shifter_SS stays uninitialised after reset. If ss_active is high right after reset, the bit leaving at line 216 corrupts fault_count_ss.
- `fault_arbiter.199.AIM.84` (high): The counts are not reset, so fault_count_run_out/fault_count_ss_out, which are driven directly by them (lines 242-243), show X or stale values during and after reset.
- `fault_arbiter.199.SDL.1` (high): fault_count_run is not reset, so fault_count_run_out (line 242) is X or stale during and after reset.
- `fault_arbiter.200.SDL.1` (high): fault_count_ss is not reset, so fault_count_ss_out (line 243) is X or stale during and after reset.
- `fault_arbiter.213.CTD.2` (high): A pwm_rise while neither state is active now updates the SS window instead of taking the idle clear at line 221. On that cycle fault_count_ss_out and fault_count_run_out are not zeroed (count_ss is updated, count_run holds), unlike the original.
- `fault_arbiter.240.AIM.128` (high): While ss_active, the mutant can assert window_trip, for example with trip_run=0, or with a count held from S_RUN when inputs go straight to S_SS. The original forces it to 0 outside S_RUN.
- `fault_arbiter.240.AIM.22` (high): With trip_run=0 in S_RUN, the original asserts window_trip (count>=0 is always true) and the mutant never does.
- `fault_arbiter.240.AIM.45` (high): With trip_run in 17..63 and all 16 run cycles faulted (count=16), the mutant trips and the original does not.
- `fault_arbiter.240.AIM.68` (high): With trip_run>=32, the signed compare treats it as negative, so a count of at most 16 makes window_trip true in S_RUN where the original's unsigned compare is false.
- `fault_arbiter.241.AIM.32` (high): With trip_ss=0 in S_SS, the original asserts window_trip_SS and the mutant does not.
- `fault_arbiter.241.AIM.46` (high): With trip_ss in 33..63 and fault_count_ss=32 (a fully faulted window, reachable), the mutant trips and the original does not.
- `fault_arbiter.91.CSK.1` (high): Without the reset branch at line 91, pwm_sync_d is X or follows pwm_sync during reset instead of being 0. If pwm_sync and run_active are high just after reset, the original sees a pwm_rise and the mutant does not, so the counts differ.
- `fault_arbiter.93.CST.1` (high): Resetting pwm_sync_d to 1 suppresses the pwm_rise the original produces on the first clock after reset when pwm_sync=1. If run_active or ss_active is high then, the original takes a sample and the mutant does not.
- `fault_arbiter.93.SDL.1` (high): pwm_sync_d is no longer reset at line 93, so it stays X or holds a stale 1 after reset. pwm_rise on the first active cycle after reset can then differ from the original.
- `fault_arbiter.97.AIM.118` (high): pwm_sync_d freezes during idle, so on re-entry to S_SS/S_RUN pwm_rise compares against the PWM level from the last switching clock instead of the last idle clock. This can add or remove a sample.
- `fault_arbiter.97.AIM.71` (high): Forcing pwm_sync_d to 0 while idle means that entering S_SS/S_RUN with pwm_sync already high creates a pwm_rise the original lacks (in the original, pwm_sync_d tracked the high pwm_sync during idle). That shifts a sample into the window and changes the count output.
