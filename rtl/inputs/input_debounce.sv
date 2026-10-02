
/*
# Filename:         input_debounce.sv

# File Description: Agreement-counter debouncer for a single synchronised
#                    fault flag. Requires the input to hold a new level for
#                    a parameterised number of clocks before the output
#                    follows it, and clears the counter on any disagreement,
#                    so only a continuously stable input qualifies.
#
#                    Asymmetric by default: assert qualification is the
#                    longer of the two, because the flags this conditions
#                    are slow by nature. A thermal event develops over tens
#                    of milliseconds and an input-rail sag over the mains or
#                    load timescale, so a few milliseconds of assert delay
#                    loses nothing real while rejecting switching-node
#                    pickup, ground bounce during load steps, and rail
#                    changeover transients. The failure this guards against
#                    is a false shutdown of a healthy board, not a missed
#                    fault.
#
#                    One instance per flag, parameters overridden at the
#                    call site. Not used on CP_trig: that flag is sampled
#                    once per switching cycle and fault_arbiter's rolling
#                    window already provides the duration filter, so a
#                    second layer would only slow the fastest protection.

#                    Instanced on OTP, UVLO and latch_stat in pmic_top, and
#                    on en_from_switch, where the parameters are overridden
#                    symmetric and long: mechanical contacts bounce equally
#                    on make and break, and a false assert or a false
#                    release are the same nuisance - a soft-start ramp
#                    started and abandoned. That instance also overrides
#                    RESET_VALUE low, since fail-safe for an enable is off,
#                    not on.

# Global variables: None

*/

`default_nettype none

module input_debounce #(
    // ASSERT_CLKS: clocks flag_in must hold high before flag_out asserts
    parameter int ASSERT_CLKS  = pmic_types_pkg::DEBOUNCE_ASSERT_CLKS,
    // RELEASE_CLKS: clocks flag_in must hold low before flag_out releases
    parameter int RELEASE_CLKS = pmic_types_pkg::DEBOUNCE_RELEASE_CLKS,
    // RESET_VALUE: value flag_out takes out of reset; 1 is fail-safe for faults;
    //              for enable 0 is fail safe. It
    //              should match the RESET_VALUE of the feeding input_sync
    parameter bit RESET_VALUE  = 1'b1
) (
    input  wire logic clk,
    input  wire logic rst_n,
    input  wire logic flag_in,     // synchronised comparator flag
    output logic      flag_out     // debounced flag to the supervisor
);

    // CNT_MAX: the longer of the two qualification times, which sizes the
    //          counter. ASSERT_CLKS is expected to be the larger, but the
    //          counter is sized for either so a call-site override cannot
    //          silently truncate.
    localparam int CNT_MAX = (ASSERT_CLKS > RELEASE_CLKS) ? ASSERT_CLKS
                                                          : RELEASE_CLKS;

    // disagree_counter: clocks for which flag_in has disagreed with flag_out
    logic [$clog2(CNT_MAX+1)-1:0] disagree_counter;
    // target_clks: qualification time for the pending transition, chosen by
    //              the direction flag_in is trying to move flag_out
    logic [$clog2(CNT_MAX+1)-1:0] target_clks;

    always_comb begin
    /*
    Purpose:
    ---
    Select the qualification time for whichever transition is pending. The
    direction is implied by flag_in differing from flag_out: if flag_in is
    high while flag_out is low, an assert is pending and ASSERT_CLKS
    applies. Picking the target combinationally keeps a single counter and
    a single compare rather than duplicating the counter per direction.
    */

    target_clks = flag_in ? ASSERT_CLKS : RELEASE_CLKS;

    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Count the clocks for which flag_in has disagreed with the believed
    state, and clear the count the moment they agree again. Only a
    continuously stable input therefore qualifies: a glitch part-way
    through an attempted transition restarts the count from zero.

    The counter saturates at its target rather than wrapping, so a flag
    that stays disagreeing cannot roll the count back under the threshold
    and un-qualify a transition that has already been earned.
    */

    if(!rst_n) begin
      disagree_counter <= 0;
    end

    else if (flag_in != flag_out) begin
      if (disagree_counter < target_clks)
        disagree_counter <= disagree_counter + 1;
    end

    else begin
      disagree_counter <= 0;
    end

    end


    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Flip the believed state once the disagreement has persisted for the
    selected qualification time. flag_out is registered rather than driven
    combinationally from the compare so that the supervisor sees a clean
    single-clock transition with no decode glitch.

    RESET_VALUE is fail-safe high for the protection flags, matching the
    input_sync instances feeding them, so the supervisor sees a fault
    asserted until the real comparator level has qualified rather than
    treating an unknown rail as healthy.
    */

    if(!rst_n) begin
      flag_out <= RESET_VALUE;
    end

    else if ((flag_in != flag_out) && (disagree_counter >= target_clks)) begin
      flag_out <= flag_in;
    end

    end


endmodule

`default_nettype wire

