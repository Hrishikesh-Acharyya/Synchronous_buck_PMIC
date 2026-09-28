/*

# Filename:         pmic_types_pkg.sv

# File Description: Shared types and constants for the synchronous buck PMIC
#                    supervisor. Every timing constant in the design is
#                    derived here from two physical quantities, the
#                    supervisor clock and the switching frequency, rather
#                    than hand-computed in each module. Changing either
#                    frequency moves every dependent count automatically.
#
#                    Imported by the RTL and the testbenches, so state
#                    encodings and shared bus widths have exactly one
#                    definition.

# Global variables: None (package-scoped types and parameters only)

*/

`default_nettype none

package pmic_types_pkg;

    // ============================================================
    // System timing - everything below derives from these two
    // ============================================================
    // CLK_HZ: supervisor clock, from the external oscillator
    localparam int CLK_HZ       = 50_000_000;
    // CONVERTOR_HZ: switching frequency of the analog modulator
    localparam int CONVERTOR_HZ = 450_000;
    // CLKS_PER_SW: clk ticks in one switching period. The true ratio is
    //              111.1, a non-integer: every counter in the
    //              design re-references to pwm_fall each cycle, so the
    //              fractional part never accumulates.
    localparam int CLKS_PER_SW  = CLK_HZ / CONVERTOR_HZ;


    // ============================================================
    // Unit conversion, elaboration time only
    // ============================================================
    // Each is evaluated by the tool during elaboration and replaced by a
    // constant, so none of these produce hardware.

    // duty_to_counts: duty cycle in percent -> on-time in clk counts
    function automatic int duty_to_counts(input int duty_pct);
        return (CLKS_PER_SW * duty_pct) / 100;
    endfunction

    // ns_to_clks: nanoseconds -> clk counts. Split into two steps because
    //             clocks-per-nanosecond is less than one and would truncate
    //             to zero in integer arithmetic.
    function automatic int ns_to_clks(input int ns);
        return ((CLK_HZ / 1_000_000) * ns) / 1000;
    endfunction

    // ms_to_clks: milliseconds -> clk counts
    function automatic int ms_to_clks(input int ms);
        return (CLK_HZ / 1000) * ms;
    endfunction

    // ms_to_sw_cycles: milliseconds -> switching cycles.
    function automatic int ms_to_sw_cycles(input int ms);
        return (CONVERTOR_HZ / 1000) * ms;
    endfunction


    // ============================================================
    // Gate driver - LM5106 at RDT = 10k
    // ============================================================
    // Turn-on is delayed by the dead-time generator, turn-off is not, so
    // every gate pulse comes out shorter than commanded:
    //     HO on-time = commanded - (t_HPLH - t_HPHL)
    //
    // LM5106_SHRINK_NS: worst-case shrinkage, from the Switching
    //                   Characteristics table at RDT = 10k. Maximum upper
    //                   turn-on delay 160 ns against typical upper turn-off
    //                   delay 32 ns. t_HPHL has no minimum specified, so 32
    //                   is the best available figure and real shrinkage
    //                   could be worse. Revisit if RDT changes - at
    //                   RDT = 100k this becomes ~658 ns.
    localparam int LM5106_SHRINK_NS = 160 - 32;
    // MIN_GATE_ON_NS: minimum on-time wanted at the gate. A design choice,
    //                 not a datasheet value: long enough for the FET to
    //                 enhance past the Miller plateau rather than dissipate
    //                 in the linear region.
    localparam int MIN_GATE_ON_NS   = 112;


    // ============================================================
    // Duty bounds
    // ============================================================
    // DIGITAL_DUTY_PCT: digital ceiling, deliberately above the 70% analog
    //                   duty clamp so the mask is a secondary backstop and
    //                   never the primary limiter in normal operation.
    localparam int DIGITAL_DUTY_PCT = 75;
    // MAX_ON_COUNTS: on-time ceiling handed to pwm_mask
    localparam int MAX_ON_COUNTS    = duty_to_counts(DIGITAL_DUTY_PCT);
    // MIN_ON_COUNTS: soft-start on-time floor. Commanded on-time must cover
    //                the driver shrinkage before any of it reaches the gate,
    //                so the floor is the sum of the two figures above - about
    //                10.8% commanded duty. 
    localparam int MIN_ON_COUNTS    = ns_to_clks(LM5106_SHRINK_NS + MIN_GATE_ON_NS);
    // ON_TIME_W: width of the on-time ceiling bus, shared by soft_start and
    //            pwm_mask. Sized to hold MAX_ON_COUNTS, hence the +1.
    localparam int ON_TIME_W        = $clog2(MAX_ON_COUNTS + 1);


    // ============================================================
    // Hiccup and strikes
    // ============================================================
    // MAX_STRIKES: hiccup retries permitted before latch_assert
    localparam int MAX_STRIKES      = 3;
    // STRIKE_W: width of the strike level bus, shared by strike_counter and
    //           hiccup_timer
    localparam int STRIKE_W         = $clog2(MAX_STRIKES + 1);
    // HICCUP_BASE_MS: cool-down for strike level 0. Each strike doubles it,
    //                 so the sequence is 5 / 10 / 20 ms.
    localparam int HICCUP_BASE_MS   = 5;
    // HICCUP_BASE_CLKS: the same interval in clk counts. Clocks, not
    //                   switching cycles: the power stage is off throughout
    //                   S_HICCUP, so there is no PWM to count.
    localparam int HICCUP_BASE_CLKS = ms_to_clks(HICCUP_BASE_MS);
    // HICCUP_TIMER_W: width of the cool-down counter, sized for the longest
    //                 interval actually used - a shift by MAX_STRIKES-1, not
    //                 by the full range STRIKE_W permits.
    localparam int HICCUP_TIMER_W   = $clog2((HICCUP_BASE_CLKS << (MAX_STRIKES-1)) + 1);


    // ============================================================
    // Fault windows
    // ============================================================
    // Thresholds differ by state because elevated current during soft start
    // is expected as the output capacitor charges from zero in FCCM, whereas
    // sustained overcurrent in S_RUN is a genuine load fault.
    //
    // WINDOW_RUN / TRIP_RUN: trailing switching cycles examined in S_RUN,
    //                        and the faulted count that trips window_trip
    localparam int WINDOW_RUN       = 16;
    localparam int TRIP_RUN         = 12;
    // WINDOW_SS / TRIP_SS: the same for S_SS, more tolerant
    localparam int WINDOW_SS        = 32;
    localparam int TRIP_SS          = 28;
    // CLEAN_RUN_MS: fault-free time in S_RUN that clears the strike count,
    //               so unrelated transients separated in time cannot
    //               accumulate into a permanent shutdown
    localparam int CLEAN_RUN_MS     = 1000;
    // CLEAN_RUN_CYCLES: the same interval in switching cycles
    localparam int CLEAN_RUN_CYCLES = ms_to_sw_cycles(CLEAN_RUN_MS);
    // CLEAN_RUN_W: width of the clean-run counter. It saturates at all-ones
    //              rather than at CLEAN_RUN_CYCLES, so the realised interval
    //              is 2**CLEAN_RUN_W cycles - about 1.17 s.
    localparam int CLEAN_RUN_W      = $clog2(CLEAN_RUN_CYCLES + 1);


    // ============================================================
    // Status
    // ============================================================
    // PGOOD_DELAY_MS: time the rail must be continuously good in S_RUN
    //                 before PGOOD asserts and the secondary circuitry is
    //                 handed over from the input LDO
    localparam int PGOOD_DELAY_MS     = 9;
    // PGOOD_DELAY_CYCLES: the same interval in switching cycles
    localparam int PGOOD_DELAY_CYCLES = ms_to_sw_cycles(PGOOD_DELAY_MS);
    // PGOOD_DELAY_W: width of the qualifying counter. As above it saturates
    //                at all-ones, so the realised delay is 2**PGOOD_DELAY_W
    //                cycles - about 9.1 ms.
    localparam int PGOOD_DELAY_W      = $clog2(PGOOD_DELAY_CYCLES + 1);


    // ============================================================
    // Supervisor FSM states
    // ============================================================
    /*
    Purpose:
    ---
    S_OFF    : converter disabled; all faults force entry here
    S_SS     : soft start active; output enabled, ramp in progress
    S_RUN    : normal regulation
    S_HICCUP : post-fault off-time; output disabled while the power stage
               cools before the next retry attempt

    Binary encoding. At 4 states on a MAX 10 this costs 2 flops against
    one-hot's 4, and the next-state logic is small enough that binary does
    not hurt timing.
    */
    typedef enum logic [1:0] {
        S_OFF    = 2'b00,
        S_SS     = 2'b01,
        S_RUN    = 2'b10,
        S_HICCUP = 2'b11
    } state_t;

endpackage

`default_nettype wire

