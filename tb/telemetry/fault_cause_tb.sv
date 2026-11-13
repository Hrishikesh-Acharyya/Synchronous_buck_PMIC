/*

# Filename:         fault_cause_tb.sv

# File Description: Directed testbench for fault_cause. Carries stimulus only -
#                   every claim lives as a property in fault_cause_sva.sv,
#                   bound to the DUT. The capture rule is a single equation
#                   the checker can state per edge, so there is no computed
#                   expected value left for check(), and checks_run is
#                   legitimately zero.
#
#                   The module has no parameters - its widths
#                   are TIMESTAMP_W and FAULT_CAUSE_W from the package - so
#                   there is nothing to override and no N-1 / N / N+1
#                   parameter boundary. timestamp_ms is an input and is driven
#                   to a distinct value per group, so a timestamp taken on the
#                   wrong edge, or re-taken, reads as a different number.
#
#                   The fault inputs arrive already synchronised and debounced
#                   in pmic_top, so they are driven as clean levels here.
#                   latch_assert is driven while the converter runs to check
#                   the LATCH bit against the module's own spec; in the full
#                   design that combination never occurs (README, known
#                   issues), which the checker header records.

# Global variables: none

*/

`timescale 1ns/1ps
`default_nettype none

module fault_cause_tb;

import pmic_types_pkg::*;
// ANSI_*: terminal colour escapes for the verdict lines. Harmless when the
//         output is redirected to a file - the codes are inert bytes - but
//         they do appear as literal escapes there, so keep them off any
//         line a script parses. The Makefile's cover check greps the
//         annotated sources, not this output, so nothing downstream breaks.
localparam string ANSI_RED   = "\033[1;31m";
localparam string ANSI_GREEN = "\033[1;32m";
localparam string ANSI_RESET = "\033[0m";


// TB_NAME: prefix on every log line, so output is attributable when
//          several testbenches run in one session
localparam string   TB_NAME         = "fault_cause_tb";
// CLK_PERIOD_NS: supervisor clock period, derived from the package rather
//                than hardcoded, so retuning CLK_HZ moves every testbench
//                with it. Real division: integer arithmetic truncates for
//                any CLK_HZ that does not divide 1e9 exactly.
localparam realtime CLK_PERIOD_NS   = 1.0e9 / real'(CLK_HZ);
// WATCHDOG_NS: hard stop so a stalled run fails instead of hanging CI. The
//              whole run is about 200 clocks of short groups, so 1000 leaves
//              room without hiding a hang.
localparam realtime WATCHDOG_NS     = 1000.0 * CLK_PERIOD_NS;  // 1000 clocks: 20 us at 50 MHz
// RESET_CLKS: clocks reset is held in do_reset()
localparam int      RESET_CLKS      = 3;
localparam realtime DRIVE_OFFSET_NS = 3.0;

// Asynchronous inputs are initialised to their INACTIVE level at
// declaration. An uninitialised logic driven straight to its active level
// transitions x -> 0, which is not a reliable negedge, so an async clear
// in the DUT never fires and the flops sit at x until the first clock edge.
logic clk;
logic rst_n               = 1'b1;
logic otp_state           = 1'b0;
logic uvlo_state          = 1'b0;
logic latch_state         = 1'b0;
logic latch_assert        = 1'b0;
logic window_trip         = 1'b0;
logic window_trip_SS      = 1'b0;
logic ss_active           = 1'b0;
logic run_active          = 1'b0;
logic fault_reg_read_done = 1'b0;
logic [TIMESTAMP_W-1:0] timestamp_ms = '0;

// DUT outputs: not read here - the properties read them through the bind
/* verilator lint_off UNUSEDSIGNAL */
logic [TIMESTAMP_W-1:0]   fault_time;
logic [FAULT_CAUSE_W-1:0] fault_reg;
/* verilator lint_on UNUSEDSIGNAL */


int unsigned checks_run    = 0;
int unsigned checks_failed = 0;


// ============================================================
// DUT
// ============================================================

fault_cause dut (
    .clk(clk), .rst_n(rst_n),
    .otp_state(otp_state), .uvlo_state(uvlo_state),
    .latch_state(latch_state), .latch_assert(latch_assert),
    .window_trip(window_trip), .window_trip_SS(window_trip_SS),
    .ss_active(ss_active), .run_active(run_active),
    .fault_reg_read_done(fault_reg_read_done), .timestamp_ms(timestamp_ms),
    .fault_time(fault_time), .fault_reg(fault_reg));


initial begin

    /*
    Purpose:
    ---
    Free-running clock. Generates the clock and nothing else - a second
    initial block assigning any signal this one touches is a race.
    */

    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2.0) clk = ~clk;

end

/*
Purpose:
---
Print $time in nanoseconds, matching the timescale a reader of this file
already has in mind.
*/

initial $timeformat(-9, 1, " ns", 10);



initial begin

    /*
    Purpose:
    ---
    Record a VCD only when asked, since the trace costs more than the run on
    a short testbench. Enabled by +WAVES, which the Makefile passes for
    WAVES=1.
    */

    if ($test$plusargs("WAVES")) begin

        $dumpfile({TB_NAME, ".vcd"});
        $dumpvars(0, fault_cause_tb);

    end

end


task automatic do_reset();

    /*
    Purpose:
    ---
    do_reset: asserts and releases reset with a genuine falling edge, so the
    DUT's async clear fires before any clock arrives. rst_n is
    driven high first for that reason even when already high.
    */

    rst_n = 1'b1;
    #1;
    rst_n = 1'b0;
    repeat (RESET_CLKS) @(posedge clk);
    #(DRIVE_OFFSET_NS);
    rst_n = 1'b1;
    repeat (RESET_CLKS) @(posedge clk);

endtask


task automatic finish_run(input string reason);

    /*
    Purpose:
    ---
    finish_run: single exit point for both the normal end and the watchdog,
    so a timeout reports a verdict instead of dying silently.
    Never $fatal - it exits before the tallies are printed.
    */

    bit passed;
    passed = (sva_pkg::sva_failures == 0) && (checks_failed == 0);
    $display("--------------------------------------------------");
    $display("exit            : %s", reason);
    $display("assertion fails : %s%0d%s",
             (sva_pkg::sva_failures == 0) ? ANSI_GREEN : ANSI_RED,
             sva_pkg::sva_failures, ANSI_RESET);
    $display("checks run      : %0d", checks_run);
    $display("checks failed   : %s%0d%s",
             (checks_failed == 0) ? ANSI_GREEN : ANSI_RED,
             checks_failed, ANSI_RESET);
    if (passed) begin

        $display("%s%s: PASS%s  (check cover hits before trusting this)",
                 ANSI_GREEN, TB_NAME, ANSI_RESET);

    end
    else begin

        $display("%s%s: FAIL%s", ANSI_RED, TB_NAME, ANSI_RESET);

    end
    $display("--------------------------------------------------");
    // tally: one plain key=value line for the run scripts (run_tb.sh reads
    //        it for the summary card; the terminal filter hides it). Keep it
    //        as is - the banner above is for people and may be reworded.
    $display("tally: checks_run=%0d checks_failed=%0d sva_failures=%0d exit=%s",
             checks_run, checks_failed, sva_pkg::sva_failures, reason);
    // $stop on failure: non-zero exit status, so make and CI see the FAIL.
    // Not $fatal - by this point the tallies are already printed.
    if (passed) $finish;
    else        $stop;

endtask


task automatic set_state(input bit ss, input bit run);

    /*
    Purpose:
    ---
    set_state: the supervisor's two flags, as one state change. Never both high
    (an input contract the checker asserts).
    */

    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    ss_active  = ss;
    run_active = run;

endtask

task automatic set_time(input logic [TIMESTAMP_W-1:0] ms);

    /*
    Purpose:
    ---
    set_time: the free-running millisecond counter, set to a value that marks
    this point in the run
    */

    @(posedge clk);
    #(DRIVE_OFFSET_NS) timestamp_ms = ms;

endtask

task automatic host_read();

    /*
    Purpose:
    ---
    host_read: the one-clock pulse reg_file raises on a completed read of the
    fault record
    */

    @(posedge clk);
    #(DRIVE_OFFSET_NS) fault_reg_read_done = 1'b1;
    @(posedge clk);
    #(DRIVE_OFFSET_NS) fault_reg_read_done = 1'b0;

endtask

task automatic pulse_cause(input string which);

    /*
    Purpose:
    ---
    pulse_cause: one cause high for two clocks. Which signal is chosen by name
    so each group reads as the fault it builds.
    */

    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    case (which)
        "otp":      otp_state      = 1'b1;
        "uvlo":     uvlo_state     = 1'b1;
        "wtrip":    window_trip    = 1'b1;
        "wtrip_ss": window_trip_SS = 1'b1;
        "latch":    latch_assert   = 1'b1;
        "ovp":      latch_state    = 1'b1;
        default: ;
    endcase
    repeat (2) @(posedge clk);
    #(DRIVE_OFFSET_NS);
    otp_state      = 1'b0;
    uvlo_state     = 1'b0;
    window_trip    = 1'b0;
    window_trip_SS = 1'b0;
    latch_assert   = 1'b0;
    latch_state    = 1'b0;
    @(posedge clk);

endtask


initial begin

    /*
    Purpose:
    ---
    Bounds the run so a stalled testbench fails rather than hanging the
    simulator. Absolute delay, so it fires even if the clock stops. Counts as
    a failure so the verdict and the exit status both report it.
    */

    #(WATCHDOG_NS);
    checks_failed++;
    finish_run("WATCHDOG - did not complete");

end


// ============================================================
// Stimulus
// ============================================================

initial begin

    /*
    Purpose:
    ---
    The test sequence: the directed groups below in order, then the verdict.
    Each group's comment names the claims it exercises.
    */

    $display("\n==== %s ====\n", TB_NAME);

    /*
    Group 1: reset.
    ---
    Record and timestamp zero. Exercises a_reset_clears.
    */

    do_reset();

    /*
    Group 2: a fault with the converter stopped.
    ---
    UVLO and OTP raised with both state flags low - a routine power-down.
    Nothing may be captured. Exercises a_hold_when_stopped and lights
    c_hold_when_stopped.
    */

    set_time(24'd10);
    pulse_cause("uvlo");
    pulse_cause("otp");

    /*
    Group 3: the first fault of an episode.
    ---
    S_RUN, timestamp 100, a UVLO dip: the UVLO bit is set and fault_time
    takes 100 on that same edge. Exercises a_capture_while_running and
    a_time_at_episode_start.
    */

    set_state(1'b0, 1'b1);
    set_time(24'd100);
    pulse_cause("uvlo");

    /*
    Group 4: a second cause in the same episode.
    ---
    Timestamp 200, OTP: the OTP bit joins the UVLO bit, which stays set
    though UVLO has cleared, and fault_time keeps 100. Exercises
    a_time_moves_by_known_path and lights c_time_held_as_causes_add.
    */

    set_time(24'd200);
    pulse_cause("otp");

    /*
    Group 5: the host reads the record.
    ---
    Both causes have gone; the read clears the record and the timestamp.
    Exercises a_read_clears.
    */

    host_read();
    repeat (2) @(posedge clk);

    /*
    Group 6: a read while a cause is still live.
    ---
    OTP held high across the read. The read clears the record on its edge,
    and the still-live cause is captured again on the next one, starting a
    new episode stamped at that edge. Lights c_read_beats_capture.
    */

    set_time(24'd300);
    @(posedge clk);
    #(DRIVE_OFFSET_NS) otp_state = 1'b1;
    repeat (2) @(posedge clk);
    host_read();
    set_time(24'd310);
    repeat (2) @(posedge clk);
    #(DRIVE_OFFSET_NS) otp_state = 1'b0;
    host_read();

    /*
    Group 7: every cause bit, one at a time.
    ---
    window_trip in S_RUN, window_trip_SS in S_SS, latch_assert, and an
    analog OVP trip (latch_state high, latch_assert low) - each read away
    before the next, so each starts its own episode at its own time. Then
    latch_state with latch_assert high: the CPLD's own trip, which must set
    LATCH and must not read as OVP. Lights the c_capture_* covers,
    c_capture_in_ss and c_ovp_vs_latch.
    */

    set_time(24'd400);
    pulse_cause("wtrip");
    host_read();
    set_state(1'b1, 1'b0);
    set_time(24'd410);
    pulse_cause("wtrip_ss");
    host_read();
    set_state(1'b0, 1'b1);
    set_time(24'd420);
    pulse_cause("latch");
    host_read();
    set_time(24'd430);
    pulse_cause("ovp");
    host_read();
    set_time(24'd440);
    @(posedge clk);
    #(DRIVE_OFFSET_NS);
    latch_state  = 1'b1;
    latch_assert = 1'b1;
    repeat (2) @(posedge clk);
    #(DRIVE_OFFSET_NS);
    latch_state  = 1'b0;
    latch_assert = 1'b0;
    host_read();

    /*
    Group 8: two episodes, no read between.
    ---
    A window_trip at 500 ms, the converter stops, then at 600 ms runs again
    and sees OTP. With no read, the two merge into one record carrying the
    earlier time, 500 - the header's limitation, asserted as intended
    behaviour by a_time_moves_by_known_path. Lights c_merge_after_quiet.
    */

    set_time(24'd500);
    pulse_cause("wtrip");
    set_state(1'b0, 1'b0);
    repeat (3) @(posedge clk);
    set_time(24'd600);
    #(DRIVE_OFFSET_NS) otp_state = 1'b1;
    set_state(1'b0, 1'b1);
    repeat (2) @(posedge clk);
    #(DRIVE_OFFSET_NS) otp_state = 1'b0;
    repeat (2) @(posedge clk);

    /*
    Group 9: reset with a record held.
    ---
    The merged record from group 8 is still there; reset clears it. Lights
    c_reset_mid_episode.
    */

    do_reset();
    set_state(1'b0, 1'b0);
    repeat (2) @(posedge clk);

    finish_run("normal end");

end

endmodule

`default_nettype wire
