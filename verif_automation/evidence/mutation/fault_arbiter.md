# Mutation record: fault_arbiter

`rtl-systemverilog/protect/fault_arbiter.sv`. Written by `tools/mutation/record.py` from `fault_arbiter.json`; every step run on this module is added, none is removed.

## Now

| | Mutants | Killed | Lint | Covers | Timeout | Survived | Stillborn | Not run | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mechanical | 193 | 141 | 31 | 0 | 0 | 21 | 0 | 0 | 89.1% |
| AI-written | 128 | 115 | 0 | 0 | 0 | 13 | 0 | 0 | 89.8% |
| all | 321 | 256 | 31 | 0 | 0 | 34 | 0 | 0 | 89.4% |

Survivors: 34 - 5 decided equivalent, 28 accepted, 1 a gap still to close, **0 not yet decided**. Score with the equivalent and accepted ones taken out: 99.7%.

## Survivors (34)

### `fault_arbiter.60.CST.2` - localparam FCNT_RUN_W: 1 -> 2

- before: `localparam int FCNT_RUN_W = $clog2(WINDOW_RUN+1);`
- after: `localparam int FCNT_RUN_W = $clog2(WINDOW_RUN+2);`
- AI judgement (step 12): **equivalent**, high confidence - With WINDOW_RUN=16, $clog2(17)=5 and $clog2(18)=5, so FCNT_RUN_W on line 60 is unchanged and nothing downstream changes.
- designer's decision (step 13): **equivalent** - same widths and values: log2(17)=log2(18)=5 and log2(33)=log2(34)=6, and a 1-bit operand cast to the narrower width is zero-extended back to the same context width

### `fault_arbiter.61.CST.2` - localparam FCNT_SS_W: 1 -> 2

- before: `localparam int FCNT_SS_W  = $clog2(WINDOW_SS+1);`
- after: `localparam int FCNT_SS_W  = $clog2(WINDOW_SS+2);`
- AI judgement (step 12): **equivalent**, high confidence - With WINDOW_SS=32, $clog2(33)=6 and $clog2(34)=6, so FCNT_SS_W on line 61 is unchanged.
- designer's decision (step 13): **equivalent** - same widths and values: log2(17)=log2(18)=5 and log2(33)=log2(34)=6, and a 1-bit operand cast to the narrower width is zero-extended back to the same context width

### `fault_arbiter.91.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 12): **plausible**, high confidence - Without the reset branch at line 91, pwm_sync_d is X or follows pwm_sync during reset instead of being 0. If pwm_sync and run_active are high just after reset, the original sees a pwm_rise and the mutant does not, so the counts differ.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.93.CST.1` - 0 -> 1

- before: `pwm_sync_d <= 0;`
- after: `pwm_sync_d <= 1;`
- AI judgement (step 12): **plausible**, high confidence - Resetting pwm_sync_d to 1 suppresses the pwm_rise the original produces on the first clock after reset when pwm_sync=1. If run_active or ss_active is high then, the original takes a sample and the mutant does not.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.93.SDL.1` - delete 'pwm_sync_d <= 0;'

- before: `pwm_sync_d <= 0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - pwm_sync_d is no longer reset at line 93, so it stays X or holds a stale 1 after reset. pwm_rise on the first active cycle after reset can then differ from the original.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.97.AIM.118` - The PWM edge detector's delayed copy pwm_sync_d is updated only while the converter is switching (S_SS or S_RUN). Through idle and hiccup it holds the PWM level from the last switching clock.

- before: `else begin`
- after: `else if (run_active || ss_active) begin`
- AI judgement (step 12): **plausible**, high confidence - pwm_sync_d freezes during idle, so on re-entry to S_SS/S_RUN pwm_rise compares against the PWM level from the last switching clock instead of the last idle clock. This can add or remove a sample.
- designer's decision (step 18): **accepted** - differ only on the first clock of S_SS or S_RUN: a missed or extra rise there adds or drops one sample (taken from the idle-cleared blanking history) in a 16- or 32-cycle window

### `fault_arbiter.97.AIM.71` - The PWM edge detector's delayed copy pwm_sync_d is cleared along with the windows and cp_delay while neither S_SS nor S_RUN is active, so entering S_SS while pwm_sync is already high produces a false cycle-boundary strobe.

- before: `else begin`
- after: `else if (!run_active && !ss_active) begin /  / pwm_sync_d <= 0; /  / end /  / else begin`
- AI judgement (step 12): **plausible**, high confidence - Forcing pwm_sync_d to 0 while idle means that entering S_SS/S_RUN with pwm_sync already high creates a pwm_rise the original lacks (in the original, pwm_sync_d tracked the high pwm_sync during idle). That shifts a sample into the window and changes the count output.
- designer's decision (step 18): **accepted** - differ only on the first clock of S_SS or S_RUN: a missed or extra rise there adds or drops one sample (taken from the idle-cleared blanking history) in a 16- or 32-cycle window

### `fault_arbiter.144.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if (!rst_n) begin`
- after: `if (1'b0) begin`
- AI judgement (step 12): **plausible**, high confidence - cp_delay is not cleared at reset (line 146 is skipped), so it can start as X or hold history shifted in while run_active was high during reset. A sample taken soon after reset then reads a different value.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.146.CST.1` - '0 -> '1

- before: `cp_delay <= '0;`
- after: `cp_delay <= '1;`
- AI judgement (step 12): **plausible**, high confidence - Resetting cp_delay to all ones means that a pwm_rise within BLANK_CLKS clocks after reset, while active, records a faulted cycle where the original records 0.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.146.SDL.1` - delete 'cp_delay <= '0;'

- before: `cp_delay <= '0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - Without the reset clear, cp_delay holds X or a stale value through reset. If the module is active straight after reset, an early pwm_rise samples it and gives a different count.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.150.AIM.97` - The blanking history is also cleared at high-side turn-off (falling edge of pwm_sync), so that it holds only low-side samples, instead of being cleared only while neither S_SS nor S_RUN is active.

- before: `else if (!run_active && !ss_active) begin`
- after: `else if ((!run_active && !ss_active) || (pwm_sync_d && !pwm_sync)) begin`
- AI judgement (step 12): **plausible**, high confidence - Clearing cp_delay on every falling PWM edge zeroes the history whenever the low-side period is shorter than BLANK_CLKS. cp_delay[4] at pwm_rise then reads 0 where the original reads cp_sync.
- designer's decision (step 17): **accepted** - differ only when the PWM low time is shorter than BLANK_CLKS (5 clocks); on the chip it is at least 28 clocks (111 clocks a period, on-time at most 83), so the tapped sample is the same

### `fault_arbiter.152.SDL.1` - delete 'cp_delay <= '0;'

- before: `cp_delay <= '0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - Without the idle clear, cp_delay keeps comparator history from before the idle period. A pwm_rise within 5 clocks of re-entering S_SS/S_RUN samples that stale bit instead of 0.
- designer's decision (step 20): **gap** - the idle clear of cp_delay is untested: no test enters S_SS (or S_RUN) with cp_sync high in the clocks before and a pwm_rise within BLANK_CLKS of entry, where stale comparator history would enter the fresh window - the case the module header gives (the CP synchroniser resets high)

### `fault_arbiter.156.AIM.43` - The blanking history only advances while PWM is low (low-side conduction), freezing during the high side, so the tap reads BLANK_CLKS low-side clocks back instead of BLANK_CLKS clocks back.

- before: `else begin`
- after: `else if (!pwm_sync) begin`
- AI judgement (step 12): **plausible**, high confidence - Freezing cp_delay while pwm_sync is high changes which cp_sync clock cp_delay[4] holds at pwm_rise, so the recorded sample can differ.
- designer's decision (step 17): **accepted** - differ only when the PWM low time is shorter than BLANK_CLKS (5 clocks); on the chip it is at least 28 clocks (111 clocks a period, on-time at most 83), so the tapped sample is the same

### `fault_arbiter.158.AIM.81` - The comparator flag is masked by 'PWM low' as it enters the blanking history, on the belief that CP is only valid in low-side conduction, so clocks taken while PWM was high are recorded as not faulted.

- before: `cp_delay <= (cp_delay << 1) | BLANK_CLKS'(cp_sync);`
- after: `cp_delay <= (cp_delay << 1) | BLANK_CLKS'(cp_sync & ~pwm_sync);`
- AI judgement (step 12): **plausible**, high confidence - If PWM was high at the clock that ends up in cp_delay[4] at pwm_rise (low period under 5 clocks), the mutant records 0 where the original records cp_sync=1.
- designer's decision (step 17): **accepted** - differ only when the PWM low time is shorter than BLANK_CLKS (5 clocks); on the chip it is at least 28 clocks (111 clocks a period, on-time at most 83), so the tapped sample is the same

### `fault_arbiter.195.BDL.1` - empty the 4-statement body of the if at line 195

- before: `if(!rst_n) begin`
- after: `if(!rst_n) begin end`
- AI judgement (step 12): **plausible**, high confidence - With an empty reset body, the counts and windows are never reset, so the count outputs show X or hold values during reset.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.195.CSK.1` - if (!rst_n) -> if (1'b0): never taken

- before: `if(!rst_n) begin`
- after: `if(1'b0) begin`
- AI judgement (step 12): **plausible**, high confidence - With no reset branch, the counts and shift registers are never initialised, and the telemetry outputs show X during reset.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.197.AIM.117` - The asynchronous reset clears the two fault counts but not the two window shift registers. The designer relies on the idle clear to zero the windows after reset is released.

- before: `fault_shifter_RUN <= 0; / fault_shifter_SS <=0; / fault_count_run <= 0;`
- after: `fault_count_run <= 0;`
- AI judgement (step 12): **plausible**, high confidence - The shift registers are not reset, so they start as X. If run_active or ss_active is high right after reset, the idle clear never runs, and the subtract of the leaving bit at line 207/216 brings X or stale bits into the counts.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.197.CST.1` - 0 -> 1

- before: `fault_shifter_RUN <= 0;`
- after: `fault_shifter_RUN <= 1;`
- AI judgement (step 12): **plausible**, high confidence - Resetting fault_shifter_RUN to 1 puts a phantom fault bit in the window. If S_RUN is entered directly after reset, it leaves after 16 rises and decrements (underflows) fault_count_run.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.197.SDL.1` - delete 'fault_shifter_RUN <= 0;'

- before: `fault_shifter_RUN <= 0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - fault_shifter_RUN stays uninitialised after reset. If run_active is high straight away, the bit leaving at line 207 is X or stale and corrupts fault_count_run.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.198.CST.1` - 0 -> 1

- before: `fault_shifter_SS <=0;`
- after: `fault_shifter_SS <=1;`
- AI judgement (step 12): **plausible**, high confidence - Resetting fault_shifter_SS to 1 puts a phantom bit in the window. If S_SS is entered directly after reset, it is subtracted after 32 rises and fault_count_ss underflows.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.198.SDL.1` - delete 'fault_shifter_SS <=0;'

- before: `fault_shifter_SS <=0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - fault_shifter_SS stays uninitialised after reset. If ss_active is high right after reset, the bit leaving at line 216 corrupts fault_count_ss.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.199.AIM.84` - The asynchronous reset clears the two shift registers but leaves both fault counts alone, relying on the idle clear to zero them after reset is released.

- before: `fault_count_run <= 0; / fault_count_ss <=0; / `
- after: ``
- AI judgement (step 12): **plausible**, high confidence - The counts are not reset, so fault_count_run_out/fault_count_ss_out, which are driven directly by them (lines 242-243), show X or stale values during and after reset.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.199.SDL.1` - delete 'fault_count_run <= 0;'

- before: `fault_count_run <= 0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - fault_count_run is not reset, so fault_count_run_out (line 242) is X or stale during and after reset.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.200.SDL.1` - delete 'fault_count_ss <=0;'

- before: `fault_count_ss <=0;`
- after: `;`
- AI judgement (step 12): **plausible**, high confidence - fault_count_ss is not reset, so fault_count_ss_out (line 243) is X or stale during and after reset.
- designer's decision (step 14): **accepted** - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them

### `fault_arbiter.213.CTD.2` - drop the term 'ss_active'

- before: `else if (pwm_rise && ss_active) begin`
- after: `else if (pwm_rise) begin`
- AI judgement (step 12): **plausible**, high confidence - A pwm_rise while neither state is active now updates the SS window instead of taking the idle clear at line 221. On that cycle fault_count_ss_out and fault_count_run_out are not zeroed (count_ss is updated, count_run holds), unlike the original.
- designer's decision (step 19): **accepted** - differs only when a pwm_rise lands on the first idle clock: the soft-start window shifts and the run window is not cleared for that one clock, then the idle clear runs; telemetry only

### `fault_arbiter.215.SIB.1` - FCNT_SS_W -> FCNT_RUN_W

- before: `fault_count_ss <= fault_count_ss + FCNT_SS_W'(cp_delay[BLANK_CLKS-1])`
- after: `fault_count_ss <= fault_count_ss + FCNT_RUN_W'(cp_delay[BLANK_CLKS-1])`
- AI judgement (step 12): **equivalent**, high confidence - The 1-bit operand is zero-extended to 5 bits instead of 6, but the context width set by the 6-bit fault_count_ss and LHS makes the value identical.
- designer's decision (step 13): **equivalent** - same widths and values: log2(17)=log2(18)=5 and log2(33)=log2(34)=6, and a 1-bit operand cast to the narrower width is zero-extended back to the same context width

### `fault_arbiter.216.SIB.1` - FCNT_SS_W -> FCNT_RUN_W

- before: `- FCNT_SS_W'(fault_shifter_SS[WINDOW_SS-1]);`
- after: `- FCNT_RUN_W'(fault_shifter_SS[WINDOW_SS-1]);`
- AI judgement (step 12): **equivalent**, high confidence - The unsigned 1-bit subtrahend is cast to 5 bits instead of 6, then extended to the 6-bit context width of line 215, so the result is the same.
- designer's decision (step 13): **equivalent** - same widths and values: log2(17)=log2(18)=5 and log2(33)=log2(34)=6, and a 1-bit operand cast to the narrower width is zero-extended back to the same context width

### `fault_arbiter.217.SIB.1` - WINDOW_SS -> WINDOW_RUN

- before: `fault_shifter_SS <= (fault_shifter_SS << 1) | WINDOW_SS'(cp_delay[BLANK_CLKS-1]);`
- after: `fault_shifter_SS <= (fault_shifter_SS << 1) | WINDOW_RUN'(cp_delay[BLANK_CLKS-1]);`
- AI judgement (step 12): **equivalent**, high confidence - The 1-bit value is cast to 16 bits instead of 32 and zero-extended to the 32-bit OR context, so fault_shifter_SS gets the same value.
- designer's decision (step 13): **equivalent** - same widths and values: log2(17)=log2(18)=5 and log2(33)=log2(34)=6, and a 1-bit operand cast to the narrower width is zero-extended back to the same context width

### `fault_arbiter.240.AIM.128` - window_trip is gated by 'converter switching' (S_SS or S_RUN) instead of S_RUN only, so the S_RUN window trip is also allowed through soft start.

- before: `always_comb window_trip    = run_active && (pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run);`
- after: `always_comb window_trip    = (run_active || ss_active) && (pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run);`
- AI judgement (step 12): **plausible**, high confidence - While ss_active, the mutant can assert window_trip, for example with trip_run=0, or with a count held from S_RUN when inputs go straight to S_SS. The original forces it to 0 outside S_RUN.
- designer's decision (step 16): **accepted** - the run count is always 0 in S_SS (S_SS is entered only from an idle state, which clears it) and trip_run is at least 1 after the reg_file clamp, so window_trip cannot fire in S_SS

### `fault_arbiter.240.AIM.22` - A TRIP_RUN threshold of zero is treated as 'S_RUN window trip disabled' instead of 'trip at any count'.

- before: `always_comb window_trip    = run_active && (pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run);`
- after: `always_comb window_trip    = run_active && (trip_run != '0) && (pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run);`
- AI judgement (step 12): **plausible**, high confidence - With trip_run=0 in S_RUN, the original asserts window_trip (count>=0 is always true) and the mutant never does.
- designer's decision (step 15): **accepted** - need a threshold outside 1..window: reg_file clamps trip_run to 1..WINDOW_RUN and trip_ss to 1..WINDOW_SS (clamp_trip_run, clamp_trip_ss), so 0, above the window and 32 or more never reach fault_arbiter

### `fault_arbiter.240.AIM.45` - A TRIP_RUN threshold above WINDOW_RUN is clamped to a full window instead of never being reached, so a completely faulted run window always trips.

- before: `always_comb window_trip    = run_active && (pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run);`
- after: `always_comb window_trip    = run_active && ((pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run) || (fault_count_run == FCNT_RUN_W'(WINDOW_RUN)));`
- AI judgement (step 12): **plausible**, high confidence - With trip_run in 17..63 and all 16 run cycles faulted (count=16), the mutant trips and the original does not.
- designer's decision (step 15): **accepted** - need a threshold outside 1..window: reg_file clamps trip_run to 1..WINDOW_RUN and trip_ss to 1..WINDOW_SS (clamp_trip_run, clamp_trip_ss), so 0, above the window and 32 or more never reach fault_arbiter

### `fault_arbiter.240.AIM.68` - The S_RUN trip compares count and threshold as signed values, so a trip_run of 32 or more (top bit set) is read as a negative threshold.

- before: `always_comb window_trip    = run_active && (pmic_types_pkg::TRIP_W'(fault_count_run) >= trip_run);`
- after: `always_comb window_trip    = run_active && ($signed(pmic_types_pkg::TRIP_W'(fault_count_run)) >= $signed(trip_run));`
- AI judgement (step 12): **plausible**, high confidence - With trip_run>=32, the signed compare treats it as negative, so a count of at most 16 makes window_trip true in S_RUN where the original's unsigned compare is false.
- designer's decision (step 15): **accepted** - need a threshold outside 1..window: reg_file clamps trip_run to 1..WINDOW_RUN and trip_ss to 1..WINDOW_SS (clamp_trip_run, clamp_trip_ss), so 0, above the window and 32 or more never reach fault_arbiter

### `fault_arbiter.241.AIM.32` - A TRIP_SS threshold of zero is treated as 'soft-start window trip disabled' instead of 'trip at any count'.

- before: `always_comb window_trip_SS = ss_active  && (fault_count_ss >= trip_ss);`
- after: `always_comb window_trip_SS = ss_active  && (trip_ss != '0) && (fault_count_ss >= trip_ss);`
- AI judgement (step 12): **plausible**, high confidence - With trip_ss=0 in S_SS, the original asserts window_trip_SS and the mutant does not.
- designer's decision (step 15): **accepted** - need a threshold outside 1..window: reg_file clamps trip_run to 1..WINDOW_RUN and trip_ss to 1..WINDOW_SS (clamp_trip_run, clamp_trip_ss), so 0, above the window and 32 or more never reach fault_arbiter

### `fault_arbiter.241.AIM.46` - A TRIP_SS threshold above WINDOW_SS is clamped to a full soft-start window instead of never being reached, so a completely faulted soft-start window always trips.

- before: `always_comb window_trip_SS = ss_active  && (fault_count_ss >= trip_ss);`
- after: `always_comb window_trip_SS = ss_active  && ((fault_count_ss >= trip_ss) || (fault_count_ss == FCNT_SS_W'(WINDOW_SS)));`
- AI judgement (step 12): **plausible**, high confidence - With trip_ss in 33..63 and fault_count_ss=32 (a fully faulted window, reachable), the mutant trips and the original does not.
- designer's decision (step 15): **accepted** - need a threshold outside 1..window: reg_file clamps trip_run to 1..WINDOW_RUN and trip_ss to 1..WINDOW_SS (clamp_trip_run, clamp_trip_ss), so 0, above the window and 32 or more never reach fault_arbiter

## History

| Step | When | Commit | What | Result |
|---:|---|---|---|---|
| 1 | 2026-11-27 09:51 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 25, accepted 24, rejected 1; `ai_runs/2026-11-27_write_mutants_17` |
| 2 | 2026-11-27 09:58 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 15, accepted 14, rejected 1; `ai_runs/2026-11-27_write_mutants_18` |
| 3 | 2026-11-27 10:05 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 22, accepted 21, rejected 1; `ai_runs/2026-11-27_write_mutants_19` |
| 4 | 2026-11-27 10:13 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 15, accepted 15, rejected 0; `ai_runs/2026-11-27_write_mutants_20` |
| 5 | 2026-11-27 10:21 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 11, accepted 11, rejected 0; `ai_runs/2026-11-27_write_mutants_21` |
| 6 | 2026-11-27 11:18 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 10, accepted 10, rejected 0; `ai_runs/2026-11-27_write_mutants_23` |
| 7 | 2026-11-27 11:25 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 9, accepted 8, rejected 1; `ai_runs/2026-11-27_write_mutants_24` |
| 8 | 2026-11-27 11:31 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 15, accepted 13, rejected 2; `ai_runs/2026-11-27_write_mutants_25` |
| 9 | 2026-11-27 11:38 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 8, accepted 8, rejected 0; `ai_runs/2026-11-27_write_mutants_26` |
| 10 | 2026-11-27 11:46 | 13c1372 | AI wrote mutants (claude-opus-5-5) | asked 50, proposed 4, accepted 4, rejected 0; `ai_runs/2026-11-27_write_mutants_27` |
| 11 | 2026-11-27 11:54 | 13c1372 | mutation run - every mutant of the module | 321 mutants: 256 killed, 31 lint, 34 survived; score 89.4% |
| 12 | 2026-11-27 11:55 | 13c1372 | AI judged survivors (claude-opus-5-5) | 34 judged, 5 called equivalent with high confidence; `ai_runs/2026-11-27_judge_survivors_3` |
| 13 | 2026-11-27 11:57 | 13c1372 | designer's decision: equivalent | fault_arbiter.60.CST.2, fault_arbiter.61.CST.2, fault_arbiter.215.SIB.1, fault_arbiter.216.SIB.1, fault_arbiter.217.SIB.1 - same widths and values: log2(17)=log2(18)=5 and log2(33)=log2(34)=6, and a 1-bit operand cast to the narrower width is zero-extended back to the same context width |
| 14 | 2026-11-27 11:57 | 13c1372 | designer's decision: accepted | fault_arbiter.91.CSK.1, fault_arbiter.93.CST.1, fault_arbiter.93.SDL.1, fault_arbiter.144.CSK.1, fault_arbiter.146.CST.1, fault_arbiter.146.SDL.1, fault_arbiter.195.BDL.1, fault_arbiter.195.CSK.1, fault_arbiter.197.CST.1, fault_arbiter.197.SDL.1, fault_arbiter.198.CST.1, fault_arbiter.198.SDL.1, fault_arbiter.199.SDL.1, fault_arbiter.200.SDL.1, fault_arbiter.197.AIM.117, fault_arbiter.199.AIM.84 - reset values never reach a sample on the chip: the supervisor is in S_OFF for at least the first clock after reset, where the idle branches clear cp_delay, both windows and both counts and pwm_sync_d tracks pwm_sync; the counts are only read through reg_file, held in the same reset. A module test entering S_SS straight out of reset would see them |
| 15 | 2026-11-27 11:57 | 13c1372 | designer's decision: accepted | fault_arbiter.240.AIM.22, fault_arbiter.241.AIM.32, fault_arbiter.240.AIM.45, fault_arbiter.241.AIM.46, fault_arbiter.240.AIM.68 - need a threshold outside 1..window: reg_file clamps trip_run to 1..WINDOW_RUN and trip_ss to 1..WINDOW_SS (clamp_trip_run, clamp_trip_ss), so 0, above the window and 32 or more never reach fault_arbiter |
| 16 | 2026-11-27 11:57 | 13c1372 | designer's decision: accepted | fault_arbiter.240.AIM.128 - the run count is always 0 in S_SS (S_SS is entered only from an idle state, which clears it) and trip_run is at least 1 after the reg_file clamp, so window_trip cannot fire in S_SS |
| 17 | 2026-11-27 11:57 | 13c1372 | designer's decision: accepted | fault_arbiter.150.AIM.97, fault_arbiter.156.AIM.43, fault_arbiter.158.AIM.81 - differ only when the PWM low time is shorter than BLANK_CLKS (5 clocks); on the chip it is at least 28 clocks (111 clocks a period, on-time at most 83), so the tapped sample is the same |
| 18 | 2026-11-27 11:57 | 13c1372 | designer's decision: accepted | fault_arbiter.97.AIM.118, fault_arbiter.97.AIM.71 - differ only on the first clock of S_SS or S_RUN: a missed or extra rise there adds or drops one sample (taken from the idle-cleared blanking history) in a 16- or 32-cycle window |
| 19 | 2026-11-27 11:57 | 13c1372 | designer's decision: accepted | fault_arbiter.213.CTD.2 - differs only when a pwm_rise lands on the first idle clock: the soft-start window shifts and the run window is not cleared for that one clock, then the idle clear runs; telemetry only |
| 20 | 2026-11-27 11:57 | 13c1372 | designer's decision: gap | fault_arbiter.152.SDL.1 - the idle clear of cp_delay is untested: no test enters S_SS (or S_RUN) with cp_sync high in the clocks before and a pwm_rise within BLANK_CLKS of entry, where stale comparator history would enter the fresh window - the case the module header gives (the CP synchroniser resets high) |
| 21 | 2026-11-27 17:04 | f2ddab0 | mutation run - ids fault_arbiter.126.DLY.2,fault_arbiter.131.EDG.1,fault_arbiter.144.CSK.2,fault_arbiter.144.UOD.1,fault_arbiter.150.AIM.24,fault_arbiter.150.CND.1,fault_arbiter.150.CSK.1,fault_arbiter.150.CSK.2,fault_arbiter.150.CTD.1,fault_arbiter.150.CTD.2,fault_arbiter.150.LCR.1,fault_arbiter.150.SIB.1,fault_arbiter.150.SIB.2,fault_arbiter.150.UOD.1,fault_arbiter.150.UOD.2,fault_arbiter.152.AIM.76,fault_arbiter.152.CST.1,fault_arbiter.156.AIM.100,fault_arbiter.156.AIM.109,fault_arbiter.156.AIM.2,fault_arbiter.158.AIM.126,fault_arbiter.158.AIM.127,fault_arbiter.158.AIM.14,fault_arbiter.158.AIM.78,fault_arbiter.158.CST.1,fault_arbiter.158.CST.2,fault_arbiter.158.CTD.1,fault_arbiter.158.CTN.1,fault_arbiter.158.CTN.2,fault_arbiter.158.LCR.1,fault_arbiter.158.SHF.1,fault_arbiter.158.VNG.1,fault_arbiter.195.CSK.2,fault_arbiter.195.UOD.1,fault_arbiter.204.AIM.69,fault_arbiter.204.AIM.74,fault_arbiter.204.AIM.87,fault_arbiter.204.CSK.1,fault_arbiter.206.AIM.114,fault_arbiter.206.AIM.3,fault_arbiter.206.AIM.31,fault_arbiter.206.AIM.39,fault_arbiter.206.AIM.41,fault_arbiter.206.AIM.60,fault_arbiter.206.AIM.64,fault_arbiter.206.SDL.1,fault_arbiter.206.STK.1,fault_arbiter.207.AIM.27,fault_arbiter.208.AIM.115,fault_arbiter.208.AIM.6,fault_arbiter.213.AIM.67,fault_arbiter.213.AIM.83,fault_arbiter.213.AIM.88,fault_arbiter.213.CSK.1,fault_arbiter.213.CTN.2,fault_arbiter.213.SIB.2,fault_arbiter.215.AIM.110,fault_arbiter.215.AIM.28,fault_arbiter.215.AIM.5,fault_arbiter.215.AIM.51,fault_arbiter.215.AIM.62,fault_arbiter.215.AIM.63,fault_arbiter.215.SDL.1,fault_arbiter.215.STK.1,fault_arbiter.216.AIM.36,fault_arbiter.216.AIM.42,fault_arbiter.217.AIM.116,fault_arbiter.217.AIM.56,fault_arbiter.82.EDG.1,fault_arbiter.99.STK.2 | 70 mutants: 70 killed; score 100.0% |

A `+` after a commit: the RTL, checkers or testbenches had uncommitted changes.

## AI-written mutants (128)

| Key | Step | Category | The fault | Now | Killed by |
|---:|---:|---|---|---|---|
| 1 | 1 | wrong_event | The cycle-boundary strobe fires on the falling edge of pwm_sync (high-side turn-off, the peak) instead of the rising edge (end of low-side conduction, the valley). | killed | a_run_count_holds, a_ss_count_holds |
| 2 | 1 | wrong_event | The blanking history cp_delay advances once per switching cycle (on pwm_rise) instead of once per clock, so the lookback is BLANK_CLKS cycles rather than BLANK_CLKS clocks. | killed | 20134 testbench checks |
| 3 | 1 | sequencing | The S_RUN window samples the live cp_sync at pwm_rise instead of the blanked cp_delay[BLANK_CLKS-1] value from before high-side turn-on. | killed | 8082 testbench checks |
| 4 | 1 | other | The soft-start count adds the live cp_sync while the SS shift register stores the blanked cp_delay sample, so the count and the window contents diverge. | killed | a_ss_count_bounded, a_ss_count_step |
| 5 | 1 | sequencing | The soft-start count adds the previous cycle's sample (fault_shifter_SS[0]) as the entering bit instead of the new sample being shifted in. | killed | 6297 testbench checks |
| 6 | 1 | field | The S_RUN window is rewritten to insert the new sample at the MSB and shift right, but the count still subtracts bit WINDOW_RUN-1 as the leaving bit, which is now the newest sample. | killed | 11225 testbench checks |
| 7 | 1 | reset_init | The soft-start window and count are cleared on every S_RUN sample, instead of being held through S_RUN for telemetry. | killed | a_ss_count_holds |
| 8 | 1 | wrong_event | The S_RUN window is also advanced during S_SS, so it enters S_RUN pre-loaded with soft-start overcurrent history. | killed | a_run_count_holds |
| 9 | 1 | wrong_event | The idle clear of both windows is qualified by pwm_rise like the update branches, so the windows clear only if PWM is still toggling while neither state is active. | killed | a_inactive_clears |
| 10 | 1 | reset_init | The idle clear resets the two counts but leaves the two shift registers holding the faulted history from before the hiccup. | killed | a_run_count_bounded, a_run_count_step +2 |
| 11 | 1 | missing_case | window_trip is gated by 'not in soft start' instead of 'in S_RUN', so it is not suppressed in the idle states. | killed | a_trip_run_confined, a_window_trip_decode |
| 12 | 1 | missing_case | window_trip_SS is gated by 'converter switching' (S_SS or S_RUN) instead of S_SS only, so the frozen soft-start count can trip it during S_RUN. | killed | a_trip_ss_confined, a_window_trip_ss_decode |
| 13 | 1 | wrong_event | The cycle-boundary strobe fires on both edges of pwm_sync, so the windows take two samples per switching cycle (valley and peak) instead of one at the valley. | killed | a_run_count_holds, a_ss_count_holds |
| 14 | 1 | sequencing | The blanking history shifts toward bit 0 with cp_sync entering at the MSB, so the tapped bit cp_delay[BLANK_CLKS-1] holds cp_sync from one clock ago instead of from BLANK_CLKS clocks ago. | killed | 17839 testbench checks |
| 15 | 1 | missing_case | The soft-start window keeps advancing during S_RUN together with the run window, instead of being frozen at its S_SS value for telemetry. | killed | a_ss_count_holds |
| 16 | 1 | reset_init | The idle clear resets the run window but leaves the soft-start window and count holding the history from before the hiccup. | killed | a_inactive_clears |
| 17 | 1 | reset_init | The idle clear resets the soft-start window but leaves the run window and count holding the history from before the hiccup. | killed | a_inactive_clears |
| 18 | 1 | sequencing | window_trip is registered, so it follows the run count and run_active one clock late. | killed | a_window_trip_decode, a_trip_run_confined |
| 19 | 1 | boundary | The S_RUN trip compares the run count for equality with trip_run instead of 'at or above' it. | killed | a_window_trip_decode |
| 20 | 1 | field | The soft-start telemetry output is gated by ss_active like window_trip_SS, so it reads 0 outside S_SS instead of reporting the held count. | killed | a_ss_count_holds, a_ss_count_step |
| 21 | 1 | sequencing | The S_RUN trip is evaluated only on the cycle-boundary strobe pwm_rise, as if the trip were sampled with the window, instead of following the run count continuously. | killed | a_window_trip_decode |
| 22 | 1 | boundary | A TRIP_RUN threshold of zero is treated as 'S_RUN window trip disabled' instead of 'trip at any count'. | survived |  |
| 23 | 1 | sequencing | The soft-start trip looks ahead at the sample being taken on pwm_rise, adding the entering bit without subtracting the leaving bit, instead of comparing the registered count. | killed | a_window_trip_ss_decode |
| 24 | 1 | reset_init | The blanking history cp_delay is not cleared while neither S_SS nor S_RUN is active, so it keeps tracking cp_sync through idle and hiccup. | killed | 37 testbench checks |
| 25 | 2 | missing_case | The S_RUN count is updated as 'increment on a faulted entering sample, else decrement on a faulted leaving sample', forgetting the case where a faulted sample enters while a faulted one leaves, so it increments instead of holding. | killed | a_run_count_bounded, a_run_count_step |
| 26 | 2 | priority | The soft-start count tests the leaving bit before the entering bit, so a cycle where a faulted sample leaves and a faulted sample enters decrements the count instead of holding it. | killed | a_ss_count_bounded, a_ss_count_step |
| 27 | 2 | field | The S_RUN count subtracts the most recent stored sample (bit 0, per the 'most recent cycle in bit 0' convention) instead of the oldest sample leaving the window at bit WINDOW_RUN-1. | killed | 11225 testbench checks |
| 28 | 2 | missing_case | Blanking is applied only to the S_RUN window: the soft-start window and its count both take the live cp_sync at pwm_rise instead of the blanked cp_delay sample. | killed | 9530 testbench checks |
| 29 | 2 | boundary | The S_RUN trip counts one faulted cycle too many when comparing with trip_run, so window_trip asserts when the window holds trip_run-1 faulted cycles. | killed | a_window_trip_decode |
| 30 | 2 | missing_case | window_trip_SS is suppressed only in S_RUN instead of being allowed only in S_SS, so it is not gated in the idle and hiccup states. | killed | a_trip_ss_confined, a_window_trip_ss_decode |
| 31 | 2 | field | The S_RUN window takes as its sample 'cp_sync high in any of the last BLANK_CLKS clocks' (OR of the whole blanking history) instead of the one comparator value from BLANK_CLKS clocks before high-side turn-on. | killed | 10231 testbench checks |
| 32 | 2 | boundary | A TRIP_SS threshold of zero is treated as 'soft-start window trip disabled' instead of 'trip at any count'. | survived |  |
| 33 | 2 | sequencing | window_trip_SS is registered, so it follows the soft-start count and ss_active one clock late. | killed | a_window_trip_ss_decode, a_trip_ss_confined |
| 34 | 2 | boundary | The soft-start trip counts one faulted cycle too many when comparing with trip_ss, so window_trip_SS asserts when the window holds trip_ss-1 faulted cycles. | killed | a_window_trip_ss_decode |
| 35 | 2 | sequencing | The S_RUN trip looks ahead at the sample being taken on pwm_rise, adding the entering bit without subtracting the leaving bit, instead of comparing the registered run count. | killed | a_window_trip_decode |
| 36 | 2 | boundary | The soft-start count subtracts the leaving bit at the run-window depth (bit WINDOW_RUN-1) instead of the oldest bit of the 32-cycle soft-start window, so fault_count_ss covers only the last 16 cycles. | killed | 11411 testbench checks |
| 37 | 2 | field | The soft-start telemetry output reports the run count of the present state while in S_RUN, instead of the soft-start count that is held through S_RUN for telemetry. | killed | a_ss_count_holds, a_ss_count_step |
| 38 | 2 | sequencing | The run-count telemetry output is registered, so it follows fault_count_run one clock late instead of showing the live count. | killed | a_run_count_holds, a_window_trip_decode +1 |
| 39 | 3 | other | The S_RUN window records the start of an overcurrent excursion (faulted cycle following a clear one) instead of the comparator level, so a sustained fault is logged only on every other cycle. | killed | 8618 testbench checks |
| 40 | 3 | field | The S_RUN count adds the live cp_sync while the S_RUN shift register stores the blanked cp_delay sample, so the run count and the run window contents diverge. | killed | a_run_count_bounded, a_run_count_step |
| 41 | 3 | sequencing | The S_RUN count adds the previous cycle's stored sample (fault_shifter_RUN[0]) as the entering bit instead of the new blanked sample being shifted in. | killed | 5908 testbench checks |
| 42 | 3 | field | The soft-start count subtracts the most recent stored sample (bit 0) instead of the oldest sample leaving the 32-cycle window at bit WINDOW_SS-1. | killed | 12127 testbench checks |
| 43 | 3 | wrong_event | The blanking history only advances while PWM is low (low-side conduction), freezing during the high side, so the tap reads BLANK_CLKS low-side clocks back instead of BLANK_CLKS clocks back. | survived |  |
| 44 | 3 | wrong_event | The run-count telemetry output is gated by run_active, so it reads 0 on the clock after S_RUN is left instead of reporting the run count before the idle clear. | killed | a_run_count_holds |
| 45 | 3 | boundary | A TRIP_RUN threshold above WINDOW_RUN is clamped to a full window instead of never being reached, so a completely faulted run window always trips. | survived |  |
| 46 | 3 | boundary | A TRIP_SS threshold above WINDOW_SS is clamped to a full soft-start window instead of never being reached, so a completely faulted soft-start window always trips. | survived |  |
| 47 | 3 | field | The 5-bit run count is widened to the 6-bit threshold width by putting the pad bit on the wrong (LSB) side, so the S_RUN trip compares twice the faulted-cycle count with trip_run. | killed | a_window_trip_decode |
| 48 | 3 | field | The entering sample is replicated across the run-count width instead of zero-extended, so a faulted cycle entering the S_RUN window adds all-ones (-1) to the count instead of +1. | killed | a_run_count_bounded, a_run_count_step |
| 49 | 3 | field | The bit leaving the soft-start window is replicated across the count width instead of zero-extended, so a faulted cycle leaving the 32-cycle window adds one to fault_count_ss instead of subtracting one. | killed | a_ss_count_bounded, a_ss_count_step |
| 50 | 3 | field | The new soft-start sample is replicated across the whole window register instead of being zero-extended into bit 0, so one faulted cycle marks every slot of the soft-start window as faulted. | killed | a_ss_count_bounded, a_ss_count_step |
| 51 | 3 | other | The soft-start window counts a cycle as faulted only if the comparator was high on every clock of the blanking history (a debounce), instead of reading the one value from BLANK_CLKS clocks before high-side turn-on. | killed | 10927 testbench checks |
| 52 | 3 | wrong_event | The soft-start window is sampled at high-side turn-off (the falling edge of pwm_sync, the peak) while the run window keeps using the valley at pwm_rise. | killed | a_ss_count_holds |
| 53 | 3 | boundary | The soft-start trip compares count and threshold as signed values, so a trip_ss of 32 or more (top bit set) is read as a negative threshold. | killed | a_window_trip_ss_decode |
| 54 | 3 | boundary | The soft-start trip line is copied from the run-trip line and widens the soft-start count from the run-count width (FCNT_RUN_W), so a full 32-cycle soft-start count loses its top bit and reads as 0. | killed | a_window_trip_ss_decode |
| 55 | 3 | sequencing | The soft-start trip is checked only on the cycle-boundary strobe pwm_rise, as if it were sampled together with the window, instead of following the soft-start count all the time. | killed | a_window_trip_ss_decode |
| 56 | 3 | field | The soft-start window is rewritten to put the new sample in at the MSB and shift right, but the count still subtracts bit WINDOW_SS-1 as the leaving bit, and that bit is now the newest sample. | killed | 12127 testbench checks |
| 57 | 3 | reset_init | The idle clear resets the two shift registers but leaves both counts holding their values from before the hiccup. | killed | a_inactive_clears, a_run_count_bounded +1 |
| 58 | 3 | other | The sample entering the soft-start window is copied across the count width instead of zero-extended, so a faulted cycle entering the window adds all-ones (-1) to fault_count_ss instead of +1. | killed | a_ss_count_bounded, a_ss_count_step |
| 59 | 3 | field | The new run-window sample is copied across the whole run shift register instead of being zero-extended into bit 0, so one faulted cycle marks every slot of the run window as faulted. | killed | a_run_count_bounded, a_run_count_step |
| 60 | 4 | field | Both windows tap the blanking history at the newest end (cp_delay[0], one clock back) instead of the oldest bit cp_delay[BLANK_CLKS-1], so there is in effect no blanking. | killed | 17839 testbench checks |
| 61 | 4 | wrong_event | The S_RUN window is sampled at high-side turn-off (the falling edge of pwm_sync, the peak), while the soft-start window keeps using the valley at pwm_rise. | killed | a_run_count_holds |
| 62 | 4 | other | The soft-start window records the start of an overcurrent excursion (a faulted cycle after a clear one) instead of the comparator level, so a sustained fault in S_SS is logged only on every other cycle. | killed | 10587 testbench checks |
| 63 | 4 | field | The soft-start window takes as its sample 'cp_sync high in any of the last BLANK_CLKS clocks' instead of the one comparator value from BLANK_CLKS clocks before high-side turn-on. | killed | 10839 testbench checks |
| 64 | 4 | field | The S_RUN window counts a cycle as faulted only if the comparator was high on every clock of the blanking history (a debounce), instead of the one value from BLANK_CLKS clocks before high-side turn-on. | killed | 10590 testbench checks |
| 65 | 4 | boundary | An overflow guard stops the run count adding the entering sample once it reaches WINDOW_RUN, but the leaving bit is still subtracted, so a full window followed by another faulted cycle drops the count to 15. | killed | a_run_count_bounded, a_run_count_step |
| 66 | 4 | boundary | The soft-start count's overflow guard is compared with the run-window depth (WINDOW_RUN, 16) instead of WINDOW_SS, so the count stops adding entering samples at 16 while still subtracting leaving ones. | killed | a_ss_count_bounded, a_ss_count_step |
| 67 | 4 | boundary | The soft-start window stops sampling once its count reaches a full window (saturation applied to the whole update), so a fully faulted window is frozen instead of rolling. | killed | 6938 testbench checks |
| 68 | 4 | boundary | The S_RUN trip compares count and threshold as signed values, so a trip_run of 32 or more (top bit set) is read as a negative threshold. | survived |  |
| 69 | 4 | boundary | The S_RUN window stops sampling once its count reaches a full window (saturation applied to the whole run update), so a fully faulted run window is frozen instead of rolling. | killed | 8269 testbench checks |
| 70 | 4 | boundary | An overflow guard at the soft-start depth stops fault_count_ss from adding the entering sample once it reaches WINDOW_SS, but the leaving bit is still subtracted, so a full 32-cycle window followed by another faulted cycle drops the count to 31. | killed | a_ss_count_bounded, a_ss_count_step |
| 71 | 4 | reset_init | The PWM edge detector's delayed copy pwm_sync_d is cleared along with the windows and cp_delay while neither S_SS nor S_RUN is active, so entering S_SS while pwm_sync is already high produces a false cycle-boundary strobe. | survived |  |
| 72 | 4 | other | The S_RUN window is written as a rotate instead of a shift, so the oldest sample leaving at bit WINDOW_RUN-1 comes back into bit 0 while the count still subtracts it. | killed | a_run_count_bounded, a_run_count_step |
| 73 | 4 | field | Copy-paste slip: the S_RUN count takes its leaving bit from the soft-start shift register, which is frozen during S_RUN, instead of from the run shift register. | killed | a_run_count_bounded, a_run_count_step |
| 74 | 4 | wrong_event | The S_RUN window stops sampling once window_trip has fired, so the count is held as evidence at the trip value instead of continuing to roll. | killed | 9934 testbench checks |
| 75 | 5 | field | Copy-paste slip: the soft-start count takes its leaving bit from the run shift register, which is held clear during S_SS, instead of from the oldest bit of the soft-start window. | killed | a_ss_count_bounded, a_ss_count_step |
| 76 | 5 | reset_init | While neither S_SS nor S_RUN is active, the blanking history is preloaded with the current comparator level instead of being cleared, so a CP flag that is high in idle or hiccup carries into the new attempt. | killed | 37 testbench checks |
| 77 | 5 | wrong_event | The windows and counts are cleared when a window trip fires instead of whenever neither S_SS nor S_RUN is active. | killed | a_run_count_holds, a_ss_count_holds +1 |
| 78 | 5 | other | The current-protection flag is treated as active-low when it enters the blanking history, so a cycle with the comparator low is counted as faulted. | killed | 23434 testbench checks |
| 79 | 5 | missing_case | The S_RUN trip also fires when the soft-start count, which is held through S_RUN only for telemetry, is at or above trip_ss. | killed | a_window_trip_decode |
| 80 | 5 | field | The run-count telemetry output reports the count of the present state, so outside S_RUN it shows the soft-start count instead of the run window's count. | killed | a_run_count_holds, a_run_count_bounded |
| 81 | 5 | other | The comparator flag is masked by 'PWM low' as it enters the blanking history, on the belief that CP is only valid in low-side conduction, so clocks taken while PWM was high are recorded as not faulted. | survived |  |
| 82 | 5 | field | The soft-start window is written as a rotate instead of a shift, so the oldest sample leaving at bit WINDOW_SS-1 comes back into bit 0 while fault_count_ss still subtracts it. | killed | a_ss_count_bounded, a_ss_count_step |
| 83 | 5 | wrong_event | The soft-start window stops sampling once window_trip_SS has fired, so its count is held at the trip value as evidence instead of continuing to roll. | killed | 10429 testbench checks |
| 84 | 5 | reset_init | The asynchronous reset clears the two shift registers but leaves both fault counts alone, relying on the idle clear to zero them after reset is released. | survived |  |
| 85 | 5 | other | The S_RUN window trip is also qualified by the live comparator flag ('overcurrent still present'), so a run window that holds trip_run faulted cycles does not trip while cp_sync is low. | killed | a_window_trip_decode |
| 86 | 6 | sequencing | The S_RUN trip is masked on the cycle-boundary strobe clock, as if the run count were mid-update there, though the count is a register and is valid on that clock. | killed | a_window_trip_decode |
| 87 | 6 | wrong_event | The S_RUN window advances only on cycles whose blanked sample is faulted, so clean cycles never push older faulted cycles out of the run window. | killed | 10304 testbench checks |
| 88 | 6 | wrong_event | The soft-start window advances only on cycles whose blanked sample is faulted, so clean soft-start cycles never age faulted cycles out of the 32-cycle window. | killed | 11217 testbench checks |
| 89 | 6 | sequencing | Only the run shift register is qualified by the cycle-boundary strobe. The run count is updated on every clock in S_RUN, so one faulted switching cycle is counted once per clock instead of once per cycle. | killed | a_run_count_holds, a_run_count_bounded +1 |
| 90 | 6 | sequencing | Only the soft-start shift register is qualified by the cycle-boundary strobe. fault_count_ss is updated on every clock in S_SS, so one faulted cycle is counted once per clock. | killed | a_ss_count_holds, a_ss_count_bounded +1 |
| 91 | 6 | sequencing | The soft-start trip is masked on the cycle-boundary strobe clock, as if fault_count_ss were mid-update there, although the count is a register and is valid on that clock. | killed | a_window_trip_ss_decode |
| 92 | 6 | other | The soft-start window trip is also qualified by the live comparator flag ('overcurrent still present'), so a soft-start window that holds trip_ss faulted cycles does not trip while cp_sync is low. | killed | a_window_trip_ss_decode |
| 93 | 6 | other | The S_RUN count is updated by 'entering XOR leaving' (the count changes only when the two bits differ) but always adds that change, forgetting the direction, so a faulted cycle leaving the run window increments fault_count_run instead of decrementing it. | killed | a_run_count_bounded, a_run_count_step |
| 94 | 6 | other | The soft-start count is updated by 'entering XOR leaving' (the count changes only when the two bits differ) but always adds that change, so a faulted cycle leaving the 32-cycle window increments fault_count_ss instead of decrementing it. | killed | a_ss_count_bounded, a_ss_count_step |
| 95 | 6 | boundary | The leaving bit is subtracted only when the window is 'full', but fullness is tested on the fault count (count == WINDOW_SS) rather than on the number of samples taken, so faulted cycles that leave a partly faulted soft-start window are never removed from fault_count_ss. | killed | a_ss_count_bounded, a_ss_count_step |
| 96 | 7 | other | window_trip is written as an 'any window tripped' summary that also carries the soft-start trip, instead of reporting only the S_RUN window. | killed | a_trip_run_confined, a_window_trip_decode |
| 97 | 7 | wrong_event | The blanking history is also cleared at high-side turn-off (falling edge of pwm_sync), so that it holds only low-side samples, instead of being cleared only while neither S_SS nor S_RUN is active. | survived |  |
| 98 | 7 | field | The bit leaving the run window is copied across the whole count width instead of zero-extended, so a faulted cycle that leaves the 16-cycle run window adds one to fault_count_run instead of taking one off. | killed | a_run_count_bounded, a_run_count_step |
| 99 | 7 | wrong_event | The run window and count are also cleared on the clock after window_trip fires, as if the trip itself should start a clean window, instead of being cleared only when neither S_SS nor S_RUN is active. | killed | a_run_count_holds |
| 100 | 7 | missing_case | The blanking history cp_delay only advances in S_RUN and forgets S_SS, so through soft start it holds the zero left by the idle clear and every soft-start sample reads as not faulted. | killed | 12193 testbench checks |
| 101 | 7 | field | The S_RUN shift register stores the live cp_sync at pwm_rise, while the run count adds the blanked cp_delay sample, so the bit later subtracted as leaving is not the bit that was added. | killed | a_run_count_bounded |
| 102 | 7 | field | The soft-start shift register stores the live cp_sync at pwm_rise, while fault_count_ss adds the blanked cp_delay sample, so the bit later subtracted as leaving is not the bit that was added. | killed | a_ss_count_bounded |
| 103 | 7 | sequencing | The soft-start telemetry output is registered, so fault_count_ss_out shows fault_count_ss one clock late instead of the live count. | killed | a_ss_count_holds, a_window_trip_ss_decode +1 |
| 104 | 8 | boundary | The leaving bit of the S_RUN window is subtracted only when the window is 'full', and fullness is tested on the fault count (count == WINDOW_RUN) instead of the number of samples taken, so faulted cycles leaving a partly faulted run window are never removed from fault_count_run. | killed | a_run_count_bounded, a_run_count_step |
| 105 | 8 | priority | The S_RUN count is updated as 'decrement on a faulted leaving sample, else increment on a faulted entering sample', so a cycle where a faulted sample leaves and a faulted one enters decrements the count instead of holding it. | killed | a_run_count_bounded, a_run_count_step |
| 106 | 8 | priority | The soft-start count is updated as 'increment on a faulted entering sample, else decrement on a faulted leaving sample', forgetting the case where a faulted sample enters while a faulted one leaves, so it increments instead of holding. | killed | a_ss_count_bounded, a_ss_count_step |
| 107 | 8 | boundary | The soft-start trip compares fault_count_ss for equality with trip_ss instead of 'at or above' it. | killed | a_window_trip_ss_decode |
| 108 | 8 | other | window_trip_SS is written as an 'any overcurrent window tripped' summary that also carries the S_RUN trip, instead of reporting only the soft-start window. | killed | a_trip_ss_confined, a_window_trip_ss_decode |
| 109 | 8 | missing_case | The blanking history cp_delay advances only in S_SS and forgets S_RUN, so through S_RUN it stays frozen at the comparator history from the end of soft start. | killed | 11409 testbench checks |
| 110 | 8 | boundary | The soft-start window and its count take the blanked comparator sample from BLANK_CLKS-1 clocks before high-side turn-on instead of BLANK_CLKS clocks before, so the soft-start lookback is one clock short while the run window keeps the full lookback. | killed | 9420 testbench checks |
| 111 | 8 | field | The soft-start telemetry output is copied from the run-count line and passes on only the run-count width (FCNT_RUN_W bits) of fault_count_ss, so a full 32-cycle soft-start count reads 0 on fault_count_ss_out. | killed | a_window_trip_ss_decode, a_ss_count_step |
| 112 | 8 | wrong_event | Only the S_RUN count is qualified by the cycle-boundary strobe. The run shift register shifts on every clock in S_RUN, so the window ages by clocks rather than by switching cycles, and the bit the count subtracts as leaving is not a sample that the count added. | killed | a_run_count_bounded, a_run_count_step |
| 113 | 8 | wrong_event | Only the soft-start count is qualified by the cycle-boundary strobe. The soft-start shift register shifts on every clock in S_SS, so the 32-bit window holds clocks rather than switching cycles, and the leaving bit fault_count_ss subtracts is not a sample that the count added. | killed | a_ss_count_bounded, a_ss_count_step |
| 114 | 8 | boundary | The S_RUN window and its count both take the blanked comparator sample from BLANK_CLKS-1 clocks before high-side turn-on instead of BLANK_CLKS clocks before, so the run lookback is one clock short while soft start keeps the full lookback. | killed | 8672 testbench checks |
| 115 | 8 | boundary | Parenthesis slip in the S_RUN window update: the new sample is ORed in before the shift, so it lands in bit 1. Each sample reaches the leaving bit WINDOW_RUN-1 one cycle early, and the run window spans 15 cycles instead of 16. | killed | 5691 testbench checks |
| 116 | 8 | boundary | Parenthesis slip in the soft-start window update: the new sample is ORed in before the shift, so it lands in bit 1 and leaves at bit WINDOW_SS-1 one cycle early. The soft-start window spans 31 cycles instead of 32. | killed | 5878 testbench checks |
| 117 | 9 | reset_init | The asynchronous reset clears the two fault counts but not the two window shift registers. The designer relies on the idle clear to zero the windows after reset is released. | survived |  |
| 118 | 9 | wrong_event | The PWM edge detector's delayed copy pwm_sync_d is updated only while the converter is switching (S_SS or S_RUN). Through idle and hiccup it holds the PWM level from the last switching clock. | survived |  |
| 119 | 9 | sequencing | The soft-start trip is gated by a registered copy of ss_active (the state from the previous clock) instead of the live ss_active, so the gate stays open for one clock after S_SS is left. | killed | a_trip_ss_confined, a_window_trip_ss_decode |
| 120 | 9 | sequencing | The S_RUN trip is gated by a registered copy of run_active instead of the live run_active, so the gate opens one clock late and closes one clock late. | killed | a_trip_run_confined, a_window_trip_decode |
| 121 | 9 | other | The S_RUN trip is made sticky: once window_trip fires it is latched until run_active falls, instead of following the run count against trip_run. | killed | a_window_trip_decode |
| 122 | 9 | wrong_event | The S_RUN threshold is captured on entry to S_RUN and held for the run, instead of trip_run being compared live. | killed | a_window_trip_decode |
| 123 | 9 | sequencing | The soft-start trip is made sticky: once window_trip_SS fires it stays latched until ss_active falls, instead of following fault_count_ss against trip_ss. | killed | a_window_trip_ss_decode |
| 124 | 9 | wrong_event | The soft-start threshold is captured on entry to S_SS and held for the whole soft start, instead of trip_ss being compared live. | killed | a_window_trip_ss_decode |
| 125 | 10 | reset_init | The soft-start window and count are also cleared on the clock after window_trip_SS fires, as if the trip itself should start a clean soft-start window, instead of being cleared only when neither S_SS nor S_RUN is active. | killed | a_ss_count_holds |
| 126 | 10 | other | The comparator flag entering the blanking history is copied across the whole cp_delay register instead of being zero-extended into bit 0, so a high cp_sync reaches the tap cp_delay[BLANK_CLKS-1] on the next clock instead of BLANK_CLKS clocks later. | killed | 21070 testbench checks |
| 127 | 10 | other | The blanking history is written as a rotate instead of a shift, so the oldest comparator bit at cp_delay[BLANK_CLKS-1] comes back into bit 0 instead of being dropped. | killed | 22743 testbench checks |
| 128 | 10 | missing_case | window_trip is gated by 'converter switching' (S_SS or S_RUN) instead of S_RUN only, so the S_RUN window trip is also allowed through soft start. | survived |  |

Rejected by the gate in step 1 (1):

- The S_RUN threshold is truncated to the 5-bit run-count width instead of the count being widened to TRIP_W, so trip_run values of 32 and above lose their top bit. - **make lint already catches it: make lint: UNUSEDSIGNAL**

Rejected by the gate in step 2 (1):

- The S_RUN window and its count both take the blanked sample from the comparator BLANK_CLKS-1 clocks before high-side turn-on instead of BLANK_CLKS clocks before, so the run lookback is one clock short while soft start keeps the full lookback. - **not legal code: %Error: protect/fault_arbiter.sv:210:3: syntax error, unexpected end**

Rejected by the gate in step 3 (1):

- The bit leaving the run window is copied across the whole count width instead of zero-extended, so a faulted cycle that leaves the 16-cycle run window adds one to fault_count_run instead of taking one off. - **not legal code: %Error: protect/fault_arbiter.sv:207:87: syntax error, unexpected ')'**

Rejected by the gate in step 7 (1):

- The S_RUN window and its count both take the blanked comparator sample from BLANK_CLKS-1 clocks before high-side turn-on instead of BLANK_CLKS clocks before, so the run lookback is one clock short while soft start keeps the full lookback. - **not legal code: %Error: protect/fault_arbiter.sv:210:3: syntax error, unexpected end**

Rejected by the gate in step 8 (2):

- Blanking is applied only to the soft-start window: the S_RUN window and its count both take the live cp_sync at pwm_rise instead of the blanked cp_delay sample. - **the lines it replaces are not in the file**
- Blanking is applied only to the soft-start window: the S_RUN window and its count both take the live cp_sync at pwm_rise instead of the blanked cp_delay sample. - **the same edit as fault_arbiter.206.AIM.3**

## Every mutant

The outcome of every run the mutant was in, oldest first, as `step:outcome`.

| Mutant | The edit | Outcomes | Killed by |
|---|---|---|---|
| `fault_arbiter.60.CST.1` | localparam FCNT_RUN_W: 1 -> 0 | 11:killed | a_run_count_step |
| `fault_arbiter.60.CST.2` | localparam FCNT_RUN_W: 1 -> 2 | 11:survived |  |
| `fault_arbiter.61.CST.1` | localparam FCNT_SS_W: 1 -> 0 | 11:killed | a_ss_count_step |
| `fault_arbiter.61.CST.2` | localparam FCNT_SS_W: 1 -> 2 | 11:survived |  |
| `fault_arbiter.82.EDG.1` | posedge clk -> negedge clk | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.91.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 11:survived |  |
| `fault_arbiter.91.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.91.UOD.1` | drop the '!' before rst_n | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.93.CST.1` | 0 -> 1 | 11:survived |  |
| `fault_arbiter.93.SDL.1` | delete 'pwm_sync_d <= 0;' | 11:survived |  |
| `fault_arbiter.97.AIM.118` | The PWM edge detector's delayed copy pwm_sync_d is updated only while the converter is switching (S_SS or S_RUN). Through idle and hiccup it holds the PWM level from the last switching clock. | 11:survived |  |
| `fault_arbiter.97.AIM.71` | The PWM edge detector's delayed copy pwm_sync_d is cleared along with the windows and cp_delay while neither S_SS nor S_RUN is active, so entering S_SS while pwm_sync is already high produces a false cycle-boundary strobe. | 11:survived |  |
| `fault_arbiter.99.SDL.1` | delete 'pwm_sync_d <= pwm_sync;' | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.99.SIB.1` | pwm_sync -> cp_sync | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.99.SIB.2` | pwm_sync -> pwm_rise | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.99.STK.1` | pwm_sync_d stuck at all-zeros (was 'pwm_sync') | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.99.STK.2` | pwm_sync_d stuck at all-ones (was 'pwm_sync') | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.99.VNG.1` | pwm_sync_d inverted (was 'pwm_sync') | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.AIM.1` | The cycle-boundary strobe fires on the falling edge of pwm_sync (high-side turn-off, the peak) instead of the rising edge (end of low-side conduction, the valley). | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.AIM.13` | The cycle-boundary strobe fires on both edges of pwm_sync, so the windows take two samples per switching cycle (valley and peak) instead of one at the valley. | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.CTD.1` | drop the term '~pwm_sync_d' | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.126.CTD.2` | drop the term 'pwm_sync' | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.CTN.1` | negate the term 'pwm_sync' | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.DLY.1` | pwm_sync_d -> pwm_sync | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.126.DLY.2` | pwm_sync -> pwm_sync_d | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.126.LCR.1` | & -> \| | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.SDL.1` | delete 'pwm_rise = ~pwm_sync_d & pwm_sync;' | 11:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `fault_arbiter.126.SIB.1` | pwm_sync -> cp_sync | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.SIB.2` | pwm_sync -> pwm_rise | 11:lint | make lint: ALWCOMBORDER, UNOPTFLAT |
| `fault_arbiter.126.STK.1` | pwm_rise stuck at all-zeros (was '~pwm_sync_d & pwm_sync') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.126.STK.2` | pwm_rise stuck at all-ones (was '~pwm_sync_d & pwm_sync') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.126.UOD.1` | drop the '~' before pwm_sync_d | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.126.VNG.1` | pwm_rise inverted (was '~pwm_sync_d & pwm_sync') | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.131.EDG.1` | posedge clk -> negedge clk | 11:killed 21:killed | 18092 testbench checks |
| `fault_arbiter.144.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 11:survived |  |
| `fault_arbiter.144.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.144.UOD.1` | drop the '!' before rst_n | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.146.CST.1` | '0 -> '1 | 11:survived |  |
| `fault_arbiter.146.SDL.1` | delete 'cp_delay <= '0;' | 11:survived |  |
| `fault_arbiter.150.AIM.24` | The blanking history cp_delay is not cleared while neither S_SS nor S_RUN is active, so it keeps tracking cp_sync through idle and hiccup. | 11:killed 21:killed | 37 testbench checks |
| `fault_arbiter.150.AIM.97` | The blanking history is also cleared at high-side turn-off (falling edge of pwm_sync), so that it holds only low-side samples, instead of being cleared only while neither S_SS nor S_RUN is active. | 11:survived |  |
| `fault_arbiter.150.CND.1` | if (!run_active && !ss_active) -> if (!(...)) | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.150.CSK.1` | if (!run_active && !ss_active) -> if (1'b0): never taken | 11:killed 21:killed | 37 testbench checks |
| `fault_arbiter.150.CSK.2` | if (!run_active && !ss_active) -> if (1'b1): always taken | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.150.CTD.1` | drop the term '!run_active' | 11:killed 21:killed | 11335 testbench checks |
| `fault_arbiter.150.CTD.2` | drop the term '!ss_active' | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.150.EDL.1` | delete the else branch at line 150 | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.150.LCR.1` | && -> \|\| | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.150.SIB.1` | run_active -> ss_active | 11:killed 21:killed | 11335 testbench checks |
| `fault_arbiter.150.SIB.2` | ss_active -> run_active | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.150.UOD.1` | drop the '!' before run_active | 11:killed 21:killed | 11335 testbench checks |
| `fault_arbiter.150.UOD.2` | drop the '!' before ss_active | 11:killed 21:killed | 12230 testbench checks |
| `fault_arbiter.152.AIM.76` | While neither S_SS nor S_RUN is active, the blanking history is preloaded with the current comparator level instead of being cleared, so a CP flag that is high in idle or hiccup carries into the new attempt. | 11:killed 21:killed | 37 testbench checks |
| `fault_arbiter.152.CST.1` | '0 -> '1 | 11:killed 21:killed | 37 testbench checks |
| `fault_arbiter.152.SDL.1` | delete 'cp_delay <= '0;' | 11:survived |  |
| `fault_arbiter.156.AIM.100` | The blanking history cp_delay only advances in S_RUN and forgets S_SS, so through soft start it holds the zero left by the idle clear and every soft-start sample reads as not faulted. | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.156.AIM.109` | The blanking history cp_delay advances only in S_SS and forgets S_RUN, so through S_RUN it stays frozen at the comparator history from the end of soft start. | 11:killed 21:killed | 11409 testbench checks |
| `fault_arbiter.156.AIM.2` | The blanking history cp_delay advances once per switching cycle (on pwm_rise) instead of once per clock, so the lookback is BLANK_CLKS cycles rather than BLANK_CLKS clocks. | 11:killed 21:killed | 20134 testbench checks |
| `fault_arbiter.156.AIM.43` | The blanking history only advances while PWM is low (low-side conduction), freezing during the high side, so the tap reads BLANK_CLKS low-side clocks back instead of BLANK_CLKS clocks back. | 11:survived |  |
| `fault_arbiter.158.AIM.126` | The comparator flag entering the blanking history is copied across the whole cp_delay register instead of being zero-extended into bit 0, so a high cp_sync reaches the tap cp_delay[BLANK_CLKS-1] on the next clock instead of BLANK_CLKS clocks later. | 11:killed 21:killed | 21070 testbench checks |
| `fault_arbiter.158.AIM.127` | The blanking history is written as a rotate instead of a shift, so the oldest comparator bit at cp_delay[BLANK_CLKS-1] comes back into bit 0 instead of being dropped. | 11:killed 21:killed | 22743 testbench checks |
| `fault_arbiter.158.AIM.14` | The blanking history shifts toward bit 0 with cp_sync entering at the MSB, so the tapped bit cp_delay[BLANK_CLKS-1] holds cp_sync from one clock ago instead of from BLANK_CLKS clocks ago. | 11:killed 21:killed | 17839 testbench checks |
| `fault_arbiter.158.AIM.78` | The current-protection flag is treated as active-low when it enters the blanking history, so a cycle with the comparator low is counted as faulted. | 11:killed 21:killed | 23434 testbench checks |
| `fault_arbiter.158.AIM.81` | The comparator flag is masked by 'PWM low' as it enters the blanking history, on the belief that CP is only valid in low-side conduction, so clocks taken while PWM was high are recorded as not faulted. | 11:survived |  |
| `fault_arbiter.158.CST.1` | 1 -> 0 | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.158.CST.2` | 1 -> 2 | 11:killed 21:killed | 17571 testbench checks |
| `fault_arbiter.158.CTD.1` | drop the term '(cp_delay << 1)' | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.158.CTD.2` | drop the term 'BLANK_CLKS'(cp_sync)' | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.158.CTN.1` | negate the term '(cp_delay << 1)' | 11:killed 21:killed | 22861 testbench checks |
| `fault_arbiter.158.CTN.2` | negate the term 'BLANK_CLKS'(cp_sync)' | 11:killed 21:killed | 22861 testbench checks |
| `fault_arbiter.158.LCR.1` | \| -> & | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.158.SDL.1` | delete 'cp_delay <= (cp_delay << 1) \| BLANK_CLKS'(cp_sync);' | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.158.SHF.1` | << -> >> | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.158.SIB.1` | cp_sync -> pwm_sync | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.158.STK.1` | cp_delay stuck at all-zeros (was '(cp_delay << 1) \| BLANK_CLKS'(cp_sync)') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.158.STK.2` | cp_delay stuck at all-ones (was '(cp_delay << 1) \| BLANK_CLKS'(cp_sync)') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.158.VNG.1` | cp_delay inverted (was '(cp_delay << 1) \| BLANK_CLKS'(cp_sync)') | 11:killed 21:killed | 23434 testbench checks |
| `fault_arbiter.165.EDG.1` | posedge clk -> negedge clk | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.195.BDL.1` | empty the 4-statement body of the if at line 195 | 11:survived |  |
| `fault_arbiter.195.CSK.1` | if (!rst_n) -> if (1'b0): never taken | 11:survived |  |
| `fault_arbiter.195.CSK.2` | if (!rst_n) -> if (1'b1): always taken | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.195.UOD.1` | drop the '!' before rst_n | 11:killed 21:killed | 23528 testbench checks |
| `fault_arbiter.197.AIM.117` | The asynchronous reset clears the two fault counts but not the two window shift registers. The designer relies on the idle clear to zero the windows after reset is released. | 11:survived |  |
| `fault_arbiter.197.CST.1` | 0 -> 1 | 11:survived |  |
| `fault_arbiter.197.SDL.1` | delete 'fault_shifter_RUN <= 0;' | 11:survived |  |
| `fault_arbiter.198.CST.1` | 0 -> 1 | 11:survived |  |
| `fault_arbiter.198.SDL.1` | delete 'fault_shifter_SS <=0;' | 11:survived |  |
| `fault_arbiter.199.AIM.84` | The asynchronous reset clears the two shift registers but leaves both fault counts alone, relying on the idle clear to zero them after reset is released. | 11:survived |  |
| `fault_arbiter.199.CST.1` | 0 -> 1 | 11:killed | a_reset_clears |
| `fault_arbiter.199.SDL.1` | delete 'fault_count_run <= 0;' | 11:survived |  |
| `fault_arbiter.200.CST.1` | 0 -> 1 | 11:killed | a_reset_clears |
| `fault_arbiter.200.SDL.1` | delete 'fault_count_ss <=0;' | 11:survived |  |
| `fault_arbiter.204.AIM.112` | Only the S_RUN count is qualified by the cycle-boundary strobe. The run shift register shifts on every clock in S_RUN, so the window ages by clocks rather than by switching cycles, and the bit the count subtracts as leaving is not a sample that the count added. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.204.AIM.61` | The S_RUN window is sampled at high-side turn-off (the falling edge of pwm_sync, the peak), while the soft-start window keeps using the valley at pwm_rise. | 11:killed | a_run_count_holds |
| `fault_arbiter.204.AIM.69` | The S_RUN window stops sampling once its count reaches a full window (saturation applied to the whole run update), so a fully faulted run window is frozen instead of rolling. | 11:killed 21:killed | 8269 testbench checks |
| `fault_arbiter.204.AIM.74` | The S_RUN window stops sampling once window_trip has fired, so the count is held as evidence at the trip value instead of continuing to roll. | 11:killed 21:killed | 9934 testbench checks |
| `fault_arbiter.204.AIM.87` | The S_RUN window advances only on cycles whose blanked sample is faulted, so clean cycles never push older faulted cycles out of the run window. | 11:killed 21:killed | 10304 testbench checks |
| `fault_arbiter.204.AIM.89` | Only the run shift register is qualified by the cycle-boundary strobe. The run count is updated on every clock in S_RUN, so one faulted switching cycle is counted once per clock instead of once per cycle. | 11:killed | a_run_count_holds, a_run_count_bounded +1 |
| `fault_arbiter.204.BDL.1` | empty the 2-statement body of the if at line 204 | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.204.CND.1` | if (pwm_rise && run_active) -> if (!(...)) | 11:killed | a_run_count_holds, a_inactive_clears |
| `fault_arbiter.204.CSK.1` | if (pwm_rise && run_active) -> if (1'b0): never taken | 11:killed 21:killed | 11335 testbench checks |
| `fault_arbiter.204.CSK.2` | if (pwm_rise && run_active) -> if (1'b1): always taken | 11:killed | a_run_count_holds, a_inactive_clears |
| `fault_arbiter.204.CTD.1` | drop the term 'pwm_rise' | 11:killed | a_run_count_holds |
| `fault_arbiter.204.CTD.2` | drop the term 'run_active' | 11:killed | a_run_count_holds |
| `fault_arbiter.204.CTN.1` | negate the term 'pwm_rise' | 11:killed | a_run_count_holds |
| `fault_arbiter.204.CTN.2` | negate the term 'run_active' | 11:killed | a_run_count_holds |
| `fault_arbiter.204.EDL.1` | delete the else branch at line 204 | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.204.LCR.1` | && -> \|\| | 11:killed | a_run_count_holds |
| `fault_arbiter.204.SIB.1` | pwm_rise -> pwm_sync | 11:killed | a_run_count_holds |
| `fault_arbiter.204.SIB.2` | run_active -> ss_active | 11:killed | a_run_count_holds |
| `fault_arbiter.206.AIM.105` | The S_RUN count is updated as 'decrement on a faulted leaving sample, else increment on a faulted entering sample', so a cycle where a faulted sample leaves and a faulted one enters decrements the count instead of holding it. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.AIM.114` | The S_RUN window and its count both take the blanked comparator sample from BLANK_CLKS-1 clocks before high-side turn-on instead of BLANK_CLKS clocks before, so the run lookback is one clock short while soft start keeps the full lookback. | 11:killed 21:killed | 8672 testbench checks |
| `fault_arbiter.206.AIM.25` | The S_RUN count is updated as 'increment on a faulted entering sample, else decrement on a faulted leaving sample', forgetting the case where a faulted sample enters while a faulted one leaves, so it increments instead of holding. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.AIM.3` | The S_RUN window samples the live cp_sync at pwm_rise instead of the blanked cp_delay[BLANK_CLKS-1] value from before high-side turn-on. | 11:killed 21:killed | 8082 testbench checks |
| `fault_arbiter.206.AIM.31` | The S_RUN window takes as its sample 'cp_sync high in any of the last BLANK_CLKS clocks' (OR of the whole blanking history) instead of the one comparator value from BLANK_CLKS clocks before high-side turn-on. | 11:killed 21:killed | 10231 testbench checks |
| `fault_arbiter.206.AIM.39` | The S_RUN window records the start of an overcurrent excursion (faulted cycle following a clear one) instead of the comparator level, so a sustained fault is logged only on every other cycle. | 11:killed 21:killed | 8618 testbench checks |
| `fault_arbiter.206.AIM.40` | The S_RUN count adds the live cp_sync while the S_RUN shift register stores the blanked cp_delay sample, so the run count and the run window contents diverge. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.AIM.41` | The S_RUN count adds the previous cycle's stored sample (fault_shifter_RUN[0]) as the entering bit instead of the new blanked sample being shifted in. | 11:killed 21:killed | 5908 testbench checks |
| `fault_arbiter.206.AIM.48` | The entering sample is replicated across the run-count width instead of zero-extended, so a faulted cycle entering the S_RUN window adds all-ones (-1) to the count instead of +1. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.AIM.60` | Both windows tap the blanking history at the newest end (cp_delay[0], one clock back) instead of the oldest bit cp_delay[BLANK_CLKS-1], so there is in effect no blanking. | 11:killed 21:killed | 17839 testbench checks |
| `fault_arbiter.206.AIM.64` | The S_RUN window counts a cycle as faulted only if the comparator was high on every clock of the blanking history (a debounce), instead of the one value from BLANK_CLKS clocks before high-side turn-on. | 11:killed 21:killed | 10590 testbench checks |
| `fault_arbiter.206.AIM.65` | An overflow guard stops the run count adding the entering sample once it reaches WINDOW_RUN, but the leaving bit is still subtracted, so a full window followed by another faulted cycle drops the count to 15. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.AIM.93` | The S_RUN count is updated by 'entering XOR leaving' (the count changes only when the two bits differ) but always adds that change, forgetting the direction, so a faulted cycle leaving the run window increments fault_count_run instead of decrementing it. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.AOR.1` | + -> - | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.SDL.1` | delete 'fault_count_run <= fault_count_run + FCNT_RUN_W'(cp_delay[BL' | 11:killed 21:killed | 11335 testbench checks |
| `fault_arbiter.206.SIB.1` | FCNT_RUN_W -> FCNT_SS_W | 11:lint | make lint: WIDTHTRUNC |
| `fault_arbiter.206.STK.1` | fault_count_run stuck at all-zeros (was 'fault_count_run + FCNT_RUN_W'(cp_delay[B') | 11:killed 21:killed | 11335 testbench checks |
| `fault_arbiter.206.STK.2` | fault_count_run stuck at all-ones (was 'fault_count_run + FCNT_RUN_W'(cp_delay[B') | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.206.VNG.1` | fault_count_run inverted (was 'fault_count_run + FCNT_RUN_W'(cp_delay[B') | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.207.AIM.104` | The leaving bit of the S_RUN window is subtracted only when the window is 'full', and fullness is tested on the fault count (count == WINDOW_RUN) instead of the number of samples taken, so faulted cycles leaving a partly faulted run window are never removed from fault_count_run. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.207.AIM.27` | The S_RUN count subtracts the most recent stored sample (bit 0, per the 'most recent cycle in bit 0' convention) instead of the oldest sample leaving the window at bit WINDOW_RUN-1. | 11:killed 21:killed | 11225 testbench checks |
| `fault_arbiter.207.AIM.73` | Copy-paste slip: the S_RUN count takes its leaving bit from the soft-start shift register, which is frozen during S_RUN, instead of from the run shift register. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.207.AIM.98` | The bit leaving the run window is copied across the whole count width instead of zero-extended, so a faulted cycle that leaves the 16-cycle run window adds one to fault_count_run instead of taking one off. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.207.AOR.1` | - -> + | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.207.SIB.1` | FCNT_RUN_W -> FCNT_SS_W | 11:lint | make lint: WIDTHTRUNC |
| `fault_arbiter.208.AIM.101` | The S_RUN shift register stores the live cp_sync at pwm_rise, while the run count adds the blanked cp_delay sample, so the bit later subtracted as leaving is not the bit that was added. | 11:killed | a_run_count_bounded |
| `fault_arbiter.208.AIM.115` | Parenthesis slip in the S_RUN window update: the new sample is ORed in before the shift, so it lands in bit 1. Each sample reaches the leaving bit WINDOW_RUN-1 one cycle early, and the run window spans 15 cycles instead of 16. | 11:killed 21:killed | 5691 testbench checks |
| `fault_arbiter.208.AIM.15` | The soft-start window keeps advancing during S_RUN together with the run window, instead of being frozen at its S_SS value for telemetry. | 11:killed | a_ss_count_holds |
| `fault_arbiter.208.AIM.59` | The new run-window sample is copied across the whole run shift register instead of being zero-extended into bit 0, so one faulted cycle marks every slot of the run window as faulted. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.AIM.6` | The S_RUN window is rewritten to insert the new sample at the MSB and shift right, but the count still subtracts bit WINDOW_RUN-1 as the leaving bit, which is now the newest sample. | 11:killed 21:killed | 11225 testbench checks |
| `fault_arbiter.208.AIM.7` | The soft-start window and count are cleared on every S_RUN sample, instead of being held through S_RUN for telemetry. | 11:killed | a_ss_count_holds |
| `fault_arbiter.208.AIM.72` | The S_RUN window is written as a rotate instead of a shift, so the oldest sample leaving at bit WINDOW_RUN-1 comes back into bit 0 while the count still subtracts it. | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.CST.1` | 1 -> 0 | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.CST.2` | 1 -> 2 | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.CTD.1` | drop the term '(fault_shifter_RUN << 1)' | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.CTD.2` | drop the term 'WINDOW_RUN'(cp_delay[BLANK_CLKS-1])' | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.CTN.1` | negate the term '(fault_shifter_RUN << 1)' | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.CTN.2` | negate the term 'WINDOW_RUN'(cp_delay[BLANK_CLKS-1])' | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.LCR.1` | \| -> & | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.SDL.1` | delete 'fault_shifter_RUN <= (fault_shifter_RUN << 1) \| WINDOW_RUN'(' | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.SHF.1` | << -> >> | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.SIB.1` | WINDOW_RUN -> WINDOW_SS | 11:lint | make lint: WIDTHTRUNC |
| `fault_arbiter.208.STK.1` | fault_shifter_RUN stuck at all-zeros (was '(fault_shifter_RUN << 1) \| WINDOW_RUN'(c') | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.STK.2` | fault_shifter_RUN stuck at all-ones (was '(fault_shifter_RUN << 1) \| WINDOW_RUN'(c') | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.208.VNG.1` | fault_shifter_RUN inverted (was '(fault_shifter_RUN << 1) \| WINDOW_RUN'(c') | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.213.AIM.113` | Only the soft-start count is qualified by the cycle-boundary strobe. The soft-start shift register shifts on every clock in S_SS, so the 32-bit window holds clocks rather than switching cycles, and the leaving bit fault_count_ss subtracts is not a sample that the count added. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.213.AIM.52` | The soft-start window is sampled at high-side turn-off (the falling edge of pwm_sync, the peak) while the run window keeps using the valley at pwm_rise. | 11:killed | a_ss_count_holds |
| `fault_arbiter.213.AIM.67` | The soft-start window stops sampling once its count reaches a full window (saturation applied to the whole update), so a fully faulted window is frozen instead of rolling. | 11:killed 21:killed | 6938 testbench checks |
| `fault_arbiter.213.AIM.83` | The soft-start window stops sampling once window_trip_SS has fired, so its count is held at the trip value as evidence instead of continuing to roll. | 11:killed 21:killed | 10429 testbench checks |
| `fault_arbiter.213.AIM.88` | The soft-start window advances only on cycles whose blanked sample is faulted, so clean soft-start cycles never age faulted cycles out of the 32-cycle window. | 11:killed 21:killed | 11217 testbench checks |
| `fault_arbiter.213.AIM.90` | Only the soft-start shift register is qualified by the cycle-boundary strobe. fault_count_ss is updated on every clock in S_SS, so one faulted cycle is counted once per clock. | 11:killed | a_ss_count_holds, a_ss_count_bounded +1 |
| `fault_arbiter.213.BDL.1` | empty the 2-statement body of the if at line 213 | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.213.CND.1` | if (pwm_rise && ss_active) -> if (!(...)) | 11:killed | a_ss_count_holds, a_inactive_clears |
| `fault_arbiter.213.CSK.1` | if (pwm_rise && ss_active) -> if (1'b0): never taken | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.213.CSK.2` | if (pwm_rise && ss_active) -> if (1'b1): always taken | 11:killed | a_ss_count_holds, a_inactive_clears |
| `fault_arbiter.213.CTD.1` | drop the term 'pwm_rise' | 11:killed | a_ss_count_holds |
| `fault_arbiter.213.CTD.2` | drop the term 'ss_active' | 11:survived |  |
| `fault_arbiter.213.CTN.1` | negate the term 'pwm_rise' | 11:killed | a_ss_count_holds |
| `fault_arbiter.213.CTN.2` | negate the term 'ss_active' | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.213.EDL.1` | delete the else branch at line 213 | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.213.LCR.1` | && -> \|\| | 11:killed | a_ss_count_holds |
| `fault_arbiter.213.SIB.1` | pwm_rise -> pwm_sync | 11:killed | a_ss_count_holds |
| `fault_arbiter.213.SIB.2` | ss_active -> run_active | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.215.AIM.106` | The soft-start count is updated as 'increment on a faulted entering sample, else decrement on a faulted leaving sample', forgetting the case where a faulted sample enters while a faulted one leaves, so it increments instead of holding. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AIM.110` | The soft-start window and its count take the blanked comparator sample from BLANK_CLKS-1 clocks before high-side turn-on instead of BLANK_CLKS clocks before, so the soft-start lookback is one clock short while the run window keeps the full lookback. | 11:killed 21:killed | 9420 testbench checks |
| `fault_arbiter.215.AIM.26` | The soft-start count tests the leaving bit before the entering bit, so a cycle where a faulted sample leaves and a faulted sample enters decrements the count instead of holding it. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AIM.28` | Blanking is applied only to the S_RUN window: the soft-start window and its count both take the live cp_sync at pwm_rise instead of the blanked cp_delay sample. | 11:killed 21:killed | 9530 testbench checks |
| `fault_arbiter.215.AIM.4` | The soft-start count adds the live cp_sync while the SS shift register stores the blanked cp_delay sample, so the count and the window contents diverge. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AIM.5` | The soft-start count adds the previous cycle's sample (fault_shifter_SS[0]) as the entering bit instead of the new sample being shifted in. | 11:killed 21:killed | 6297 testbench checks |
| `fault_arbiter.215.AIM.51` | The soft-start window counts a cycle as faulted only if the comparator was high on every clock of the blanking history (a debounce), instead of reading the one value from BLANK_CLKS clocks before high-side turn-on. | 11:killed 21:killed | 10927 testbench checks |
| `fault_arbiter.215.AIM.58` | The sample entering the soft-start window is copied across the count width instead of zero-extended, so a faulted cycle entering the window adds all-ones (-1) to fault_count_ss instead of +1. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AIM.62` | The soft-start window records the start of an overcurrent excursion (a faulted cycle after a clear one) instead of the comparator level, so a sustained fault in S_SS is logged only on every other cycle. | 11:killed 21:killed | 10587 testbench checks |
| `fault_arbiter.215.AIM.63` | The soft-start window takes as its sample 'cp_sync high in any of the last BLANK_CLKS clocks' instead of the one comparator value from BLANK_CLKS clocks before high-side turn-on. | 11:killed 21:killed | 10839 testbench checks |
| `fault_arbiter.215.AIM.66` | The soft-start count's overflow guard is compared with the run-window depth (WINDOW_RUN, 16) instead of WINDOW_SS, so the count stops adding entering samples at 16 while still subtracting leaving ones. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AIM.70` | An overflow guard at the soft-start depth stops fault_count_ss from adding the entering sample once it reaches WINDOW_SS, but the leaving bit is still subtracted, so a full 32-cycle window followed by another faulted cycle drops the count to 31. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AIM.94` | The soft-start count is updated by 'entering XOR leaving' (the count changes only when the two bits differ) but always adds that change, so a faulted cycle leaving the 32-cycle window increments fault_count_ss instead of decrementing it. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.AOR.1` | + -> - | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.SDL.1` | delete 'fault_count_ss <= fault_count_ss + FCNT_SS_W'(cp_delay[BLANK' | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.215.SIB.1` | FCNT_SS_W -> FCNT_RUN_W | 11:survived |  |
| `fault_arbiter.215.STK.1` | fault_count_ss stuck at all-zeros (was 'fault_count_ss + FCNT_SS_W'(cp_delay[BLA') | 11:killed 21:killed | 12193 testbench checks |
| `fault_arbiter.215.STK.2` | fault_count_ss stuck at all-ones (was 'fault_count_ss + FCNT_SS_W'(cp_delay[BLA') | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.215.VNG.1` | fault_count_ss inverted (was 'fault_count_ss + FCNT_SS_W'(cp_delay[BLA') | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.216.AIM.36` | The soft-start count subtracts the leaving bit at the run-window depth (bit WINDOW_RUN-1) instead of the oldest bit of the 32-cycle soft-start window, so fault_count_ss covers only the last 16 cycles. | 11:killed 21:killed | 11411 testbench checks |
| `fault_arbiter.216.AIM.42` | The soft-start count subtracts the most recent stored sample (bit 0) instead of the oldest sample leaving the 32-cycle window at bit WINDOW_SS-1. | 11:killed 21:killed | 12127 testbench checks |
| `fault_arbiter.216.AIM.49` | The bit leaving the soft-start window is replicated across the count width instead of zero-extended, so a faulted cycle leaving the 32-cycle window adds one to fault_count_ss instead of subtracting one. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.216.AIM.75` | Copy-paste slip: the soft-start count takes its leaving bit from the run shift register, which is held clear during S_SS, instead of from the oldest bit of the soft-start window. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.216.AIM.95` | The leaving bit is subtracted only when the window is 'full', but fullness is tested on the fault count (count == WINDOW_SS) rather than on the number of samples taken, so faulted cycles that leave a partly faulted soft-start window are never removed from fault_count_ss. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.216.AOR.1` | - -> + | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.216.SIB.1` | FCNT_SS_W -> FCNT_RUN_W | 11:survived |  |
| `fault_arbiter.217.AIM.102` | The soft-start shift register stores the live cp_sync at pwm_rise, while fault_count_ss adds the blanked cp_delay sample, so the bit later subtracted as leaving is not the bit that was added. | 11:killed | a_ss_count_bounded |
| `fault_arbiter.217.AIM.116` | Parenthesis slip in the soft-start window update: the new sample is ORed in before the shift, so it lands in bit 1 and leaves at bit WINDOW_SS-1 one cycle early. The soft-start window spans 31 cycles instead of 32. | 11:killed 21:killed | 5878 testbench checks |
| `fault_arbiter.217.AIM.50` | The new soft-start sample is replicated across the whole window register instead of being zero-extended into bit 0, so one faulted cycle marks every slot of the soft-start window as faulted. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.AIM.56` | The soft-start window is rewritten to put the new sample in at the MSB and shift right, but the count still subtracts bit WINDOW_SS-1 as the leaving bit, and that bit is now the newest sample. | 11:killed 21:killed | 12127 testbench checks |
| `fault_arbiter.217.AIM.8` | The S_RUN window is also advanced during S_SS, so it enters S_RUN pre-loaded with soft-start overcurrent history. | 11:killed | a_run_count_holds |
| `fault_arbiter.217.AIM.82` | The soft-start window is written as a rotate instead of a shift, so the oldest sample leaving at bit WINDOW_SS-1 comes back into bit 0 while fault_count_ss still subtracts it. | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.CST.1` | 1 -> 0 | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.CST.2` | 1 -> 2 | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.CTD.1` | drop the term '(fault_shifter_SS << 1)' | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.CTD.2` | drop the term 'WINDOW_SS'(cp_delay[BLANK_CLKS-1])' | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.CTN.1` | negate the term '(fault_shifter_SS << 1)' | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.CTN.2` | negate the term 'WINDOW_SS'(cp_delay[BLANK_CLKS-1])' | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.LCR.1` | \| -> & | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.SDL.1` | delete 'fault_shifter_SS <= (fault_shifter_SS << 1) \| WINDOW_SS'(cp_' | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.SHF.1` | << -> >> | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.SIB.1` | WINDOW_SS -> WINDOW_RUN | 11:survived |  |
| `fault_arbiter.217.STK.1` | fault_shifter_SS stuck at all-zeros (was '(fault_shifter_SS << 1) \| WINDOW_SS'(cp_') | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.STK.2` | fault_shifter_SS stuck at all-ones (was '(fault_shifter_SS << 1) \| WINDOW_SS'(cp_') | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.217.VNG.1` | fault_shifter_SS inverted (was '(fault_shifter_SS << 1) \| WINDOW_SS'(cp_') | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.221.AIM.125` | The soft-start window and count are also cleared on the clock after window_trip_SS fires, as if the trip itself should start a clean soft-start window, instead of being cleared only when neither S_SS nor S_RUN is active. | 11:killed | a_ss_count_holds |
| `fault_arbiter.221.AIM.77` | The windows and counts are cleared when a window trip fires instead of whenever neither S_SS nor S_RUN is active. | 11:killed | a_run_count_holds, a_ss_count_holds +1 |
| `fault_arbiter.221.AIM.9` | The idle clear of both windows is qualified by pwm_rise like the update branches, so the windows clear only if PWM is still toggling while neither state is active. | 11:killed | a_inactive_clears |
| `fault_arbiter.221.AIM.99` | The run window and count are also cleared on the clock after window_trip fires, as if the trip itself should start a clean window, instead of being cleared only when neither S_SS nor S_RUN is active. | 11:killed | a_run_count_holds |
| `fault_arbiter.221.BDL.1` | empty the 4-statement body of the if at line 221 | 11:killed | a_inactive_clears |
| `fault_arbiter.221.CND.1` | if (!run_active && !ss_active) -> if (!(...)) | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.221.CSK.1` | if (!run_active && !ss_active) -> if (1'b1): always taken | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.221.CTD.1` | drop the term '!run_active' | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.221.CTD.2` | drop the term '!ss_active' | 11:killed | a_ss_count_holds |
| `fault_arbiter.221.EDL.1` | delete the else branch at line 221 | 11:killed | a_inactive_clears |
| `fault_arbiter.221.LCR.1` | && -> \|\| | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.221.SIB.1` | run_active -> ss_active | 11:killed | a_run_count_holds, a_ss_count_holds |
| `fault_arbiter.221.SIB.2` | ss_active -> run_active | 11:killed | a_ss_count_holds |
| `fault_arbiter.221.UOD.1` | drop the '!' before run_active | 11:killed | a_run_count_holds, a_inactive_clears +1 |
| `fault_arbiter.221.UOD.2` | drop the '!' before ss_active | 11:killed | a_ss_count_holds, a_inactive_clears +1 |
| `fault_arbiter.223.AIM.10` | The idle clear resets the two counts but leaves the two shift registers holding the faulted history from before the hiccup. | 11:killed | a_run_count_bounded, a_run_count_step +2 |
| `fault_arbiter.223.AIM.17` | The idle clear resets the soft-start window but leaves the run window and count holding the history from before the hiccup. | 11:killed | a_inactive_clears |
| `fault_arbiter.223.CST.1` | 0 -> 1 | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.223.SDL.1` | delete 'fault_shifter_RUN <= 0;' | 11:killed | a_run_count_bounded, a_run_count_step |
| `fault_arbiter.224.AIM.16` | The idle clear resets the run window but leaves the soft-start window and count holding the history from before the hiccup. | 11:killed | a_inactive_clears |
| `fault_arbiter.224.AIM.57` | The idle clear resets the two shift registers but leaves both counts holding their values from before the hiccup. | 11:killed | a_inactive_clears, a_run_count_bounded +1 |
| `fault_arbiter.224.CST.1` | 0 -> 1 | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.224.SDL.1` | delete 'fault_shifter_SS <= 0;' | 11:killed | a_ss_count_bounded, a_ss_count_step |
| `fault_arbiter.225.CST.1` | 0 -> 1 | 11:killed | a_inactive_clears, a_run_count_bounded |
| `fault_arbiter.225.SDL.1` | delete 'fault_count_run <=0;' | 11:killed | a_inactive_clears, a_run_count_bounded |
| `fault_arbiter.226.CST.1` | 0 -> 1 | 11:killed | a_inactive_clears, a_ss_count_bounded |
| `fault_arbiter.226.SDL.1` | delete 'fault_count_ss <= 0;' | 11:killed | a_inactive_clears, a_ss_count_bounded |
| `fault_arbiter.240.AIM.11` | window_trip is gated by 'not in soft start' instead of 'in S_RUN', so it is not suppressed in the idle states. | 11:killed | a_trip_run_confined, a_window_trip_decode |
| `fault_arbiter.240.AIM.120` | The S_RUN trip is gated by a registered copy of run_active instead of the live run_active, so the gate opens one clock late and closes one clock late. | 11:killed | a_trip_run_confined, a_window_trip_decode |
| `fault_arbiter.240.AIM.121` | The S_RUN trip is made sticky: once window_trip fires it is latched until run_active falls, instead of following the run count against trip_run. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.122` | The S_RUN threshold is captured on entry to S_RUN and held for the run, instead of trip_run being compared live. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.128` | window_trip is gated by 'converter switching' (S_SS or S_RUN) instead of S_RUN only, so the S_RUN window trip is also allowed through soft start. | 11:survived |  |
| `fault_arbiter.240.AIM.18` | window_trip is registered, so it follows the run count and run_active one clock late. | 11:killed | a_window_trip_decode, a_trip_run_confined |
| `fault_arbiter.240.AIM.19` | The S_RUN trip compares the run count for equality with trip_run instead of 'at or above' it. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.21` | The S_RUN trip is evaluated only on the cycle-boundary strobe pwm_rise, as if the trip were sampled with the window, instead of following the run count continuously. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.22` | A TRIP_RUN threshold of zero is treated as 'S_RUN window trip disabled' instead of 'trip at any count'. | 11:survived |  |
| `fault_arbiter.240.AIM.29` | The S_RUN trip counts one faulted cycle too many when comparing with trip_run, so window_trip asserts when the window holds trip_run-1 faulted cycles. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.35` | The S_RUN trip looks ahead at the sample being taken on pwm_rise, adding the entering bit without subtracting the leaving bit, instead of comparing the registered run count. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.45` | A TRIP_RUN threshold above WINDOW_RUN is clamped to a full window instead of never being reached, so a completely faulted run window always trips. | 11:survived |  |
| `fault_arbiter.240.AIM.47` | The 5-bit run count is widened to the 6-bit threshold width by putting the pad bit on the wrong (LSB) side, so the S_RUN trip compares twice the faulted-cycle count with trip_run. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.68` | The S_RUN trip compares count and threshold as signed values, so a trip_run of 32 or more (top bit set) is read as a negative threshold. | 11:survived |  |
| `fault_arbiter.240.AIM.79` | The S_RUN trip also fires when the soft-start count, which is held through S_RUN only for telemetry, is at or above trip_ss. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.85` | The S_RUN window trip is also qualified by the live comparator flag ('overcurrent still present'), so a run window that holds trip_run faulted cycles does not trip while cp_sync is low. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.86` | The S_RUN trip is masked on the cycle-boundary strobe clock, as if the run count were mid-update there, though the count is a register and is valid on that clock. | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.AIM.96` | window_trip is written as an 'any window tripped' summary that also carries the soft-start trip, instead of reporting only the S_RUN window. | 11:killed | a_trip_run_confined, a_window_trip_decode |
| `fault_arbiter.240.CTD.1` | drop the term 'run_active' | 11:killed | a_trip_run_confined, a_window_trip_decode |
| `fault_arbiter.240.CTD.2` | drop the term '(pmic_types_pkg::TRIP_W'(fault_count_run' | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.240.CTN.1` | negate the term 'run_active' | 11:killed | a_window_trip_decode, a_trip_run_confined |
| `fault_arbiter.240.CTN.2` | negate the term '(pmic_types_pkg::TRIP_W'(fault_count_run' | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.LCR.1` | && -> \|\| | 11:killed | a_window_trip_decode, a_trip_run_confined |
| `fault_arbiter.240.ROR.1` | >= -> <= | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.ROR.2` | >= -> > | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.SDL.1` | delete 'window_trip = run_active && (pmic_types_pkg::TRIP_W'(fault_c' | 11:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `fault_arbiter.240.SIB.1` | run_active -> ss_active | 11:killed | a_window_trip_decode |
| `fault_arbiter.240.SIB.2` | trip_run -> trip_ss | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.240.STK.1` | window_trip stuck at all-zeros (was 'run_active && (pmic_types_pkg::TRIP_W'(f') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.240.STK.2` | window_trip stuck at all-ones (was 'run_active && (pmic_types_pkg::TRIP_W'(f') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.240.VNG.1` | window_trip inverted (was 'run_active && (pmic_types_pkg::TRIP_W'(f') | 11:killed | a_reset_clears, a_trip_run_confined +1 |
| `fault_arbiter.241.AIM.107` | The soft-start trip compares fault_count_ss for equality with trip_ss instead of 'at or above' it. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.108` | window_trip_SS is written as an 'any overcurrent window tripped' summary that also carries the S_RUN trip, instead of reporting only the soft-start window. | 11:killed | a_trip_ss_confined, a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.119` | The soft-start trip is gated by a registered copy of ss_active (the state from the previous clock) instead of the live ss_active, so the gate stays open for one clock after S_SS is left. | 11:killed | a_trip_ss_confined, a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.12` | window_trip_SS is gated by 'converter switching' (S_SS or S_RUN) instead of S_SS only, so the frozen soft-start count can trip it during S_RUN. | 11:killed | a_trip_ss_confined, a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.123` | The soft-start trip is made sticky: once window_trip_SS fires it stays latched until ss_active falls, instead of following fault_count_ss against trip_ss. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.124` | The soft-start threshold is captured on entry to S_SS and held for the whole soft start, instead of trip_ss being compared live. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.23` | The soft-start trip looks ahead at the sample being taken on pwm_rise, adding the entering bit without subtracting the leaving bit, instead of comparing the registered count. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.30` | window_trip_SS is suppressed only in S_RUN instead of being allowed only in S_SS, so it is not gated in the idle and hiccup states. | 11:killed | a_trip_ss_confined, a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.32` | A TRIP_SS threshold of zero is treated as 'soft-start window trip disabled' instead of 'trip at any count'. | 11:survived |  |
| `fault_arbiter.241.AIM.33` | window_trip_SS is registered, so it follows the soft-start count and ss_active one clock late. | 11:killed | a_window_trip_ss_decode, a_trip_ss_confined |
| `fault_arbiter.241.AIM.34` | The soft-start trip counts one faulted cycle too many when comparing with trip_ss, so window_trip_SS asserts when the window holds trip_ss-1 faulted cycles. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.46` | A TRIP_SS threshold above WINDOW_SS is clamped to a full soft-start window instead of never being reached, so a completely faulted soft-start window always trips. | 11:survived |  |
| `fault_arbiter.241.AIM.53` | The soft-start trip compares count and threshold as signed values, so a trip_ss of 32 or more (top bit set) is read as a negative threshold. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.54` | The soft-start trip line is copied from the run-trip line and widens the soft-start count from the run-count width (FCNT_RUN_W), so a full 32-cycle soft-start count loses its top bit and reads as 0. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.55` | The soft-start trip is checked only on the cycle-boundary strobe pwm_rise, as if it were sampled together with the window, instead of following the soft-start count all the time. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.91` | The soft-start trip is masked on the cycle-boundary strobe clock, as if fault_count_ss were mid-update there, although the count is a register and is valid on that clock. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.AIM.92` | The soft-start window trip is also qualified by the live comparator flag ('overcurrent still present'), so a soft-start window that holds trip_ss faulted cycles does not trip while cp_sync is low. | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.CTD.1` | drop the term 'ss_active' | 11:killed | a_trip_ss_confined, a_window_trip_ss_decode |
| `fault_arbiter.241.CTD.2` | drop the term '(fault_count_ss >= trip_ss)' | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.241.CTN.1` | negate the term 'ss_active' | 11:killed | a_window_trip_ss_decode, a_trip_ss_confined |
| `fault_arbiter.241.CTN.2` | negate the term '(fault_count_ss >= trip_ss)' | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.LCR.1` | && -> \|\| | 11:killed | a_window_trip_ss_decode, a_trip_ss_confined |
| `fault_arbiter.241.ROR.1` | >= -> <= | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.ROR.2` | >= -> > | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.241.SDL.1` | delete 'window_trip_SS = ss_active && (fault_count_ss >= trip_ss);' | 11:lint | make lint: UNDRIVEN, UNUSEDSIGNAL |
| `fault_arbiter.241.SIB.1` | ss_active -> run_active | 11:killed | a_window_trip_ss_decode, a_trip_ss_confined |
| `fault_arbiter.241.SIB.2` | trip_ss -> trip_run | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.241.STK.1` | window_trip_SS stuck at all-zeros (was 'ss_active && (fault_count_ss >= trip_ss)') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.241.STK.2` | window_trip_SS stuck at all-ones (was 'ss_active && (fault_count_ss >= trip_ss)') | 11:lint | make lint: UNUSEDSIGNAL |
| `fault_arbiter.241.VNG.1` | window_trip_SS inverted (was 'ss_active && (fault_count_ss >= trip_ss)') | 11:killed | a_reset_clears, a_trip_ss_confined +1 |
| `fault_arbiter.242.AIM.38` | The run-count telemetry output is registered, so it follows fault_count_run one clock late instead of showing the live count. | 11:killed | a_run_count_holds, a_window_trip_decode +1 |
| `fault_arbiter.242.AIM.44` | The run-count telemetry output is gated by run_active, so it reads 0 on the clock after S_RUN is left instead of reporting the run count before the idle clear. | 11:killed | a_run_count_holds |
| `fault_arbiter.242.AIM.80` | The run-count telemetry output reports the count of the present state, so outside S_RUN it shows the soft-start count instead of the run window's count. | 11:killed | a_run_count_holds, a_run_count_bounded |
| `fault_arbiter.242.SDL.1` | delete 'fault_count_run_out = fault_count_run;' | 11:lint | make lint: UNDRIVEN |
| `fault_arbiter.242.STK.1` | fault_count_run_out stuck at all-zeros (was 'fault_count_run') | 11:killed | a_window_trip_decode |
| `fault_arbiter.242.STK.2` | fault_count_run_out stuck at all-ones (was 'fault_count_run') | 11:killed | a_reset_clears, a_run_count_bounded +2 |
| `fault_arbiter.242.VNG.1` | fault_count_run_out inverted (was 'fault_count_run') | 11:killed | a_reset_clears, a_run_count_bounded +2 |
| `fault_arbiter.243.AIM.103` | The soft-start telemetry output is registered, so fault_count_ss_out shows fault_count_ss one clock late instead of the live count. | 11:killed | a_ss_count_holds, a_window_trip_ss_decode +1 |
| `fault_arbiter.243.AIM.111` | The soft-start telemetry output is copied from the run-count line and passes on only the run-count width (FCNT_RUN_W bits) of fault_count_ss, so a full 32-cycle soft-start count reads 0 on fault_count_ss_out. | 11:killed | a_window_trip_ss_decode, a_ss_count_step |
| `fault_arbiter.243.AIM.20` | The soft-start telemetry output is gated by ss_active like window_trip_SS, so it reads 0 outside S_SS instead of reporting the held count. | 11:killed | a_ss_count_holds, a_ss_count_step |
| `fault_arbiter.243.AIM.37` | The soft-start telemetry output reports the run count of the present state while in S_RUN, instead of the soft-start count that is held through S_RUN for telemetry. | 11:killed | a_ss_count_holds, a_ss_count_step |
| `fault_arbiter.243.SDL.1` | delete 'fault_count_ss_out = fault_count_ss;' | 11:lint | make lint: UNDRIVEN |
| `fault_arbiter.243.STK.1` | fault_count_ss_out stuck at all-zeros (was 'fault_count_ss') | 11:killed | a_window_trip_ss_decode |
| `fault_arbiter.243.STK.2` | fault_count_ss_out stuck at all-ones (was 'fault_count_ss') | 11:killed | a_reset_clears, a_ss_count_bounded +2 |
| `fault_arbiter.243.VNG.1` | fault_count_ss_out inverted (was 'fault_count_ss') | 11:killed | a_reset_clears, a_ss_count_bounded +2 |
