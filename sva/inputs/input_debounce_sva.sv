/*

# Filename:         input_debounce_sva.sv

# File Description: Concurrent assertion checker for input_debounce. Attached
#                   with bind so the RTL source carries no assertion
#                   constructs and the sv2v / Yosys ASIC path never sees them.
#                   All three parameters are passed through from the bound
#                   instance, so each of the seven call sites in pmic_top is
#                   checked against its own qualification times and reset
#                   level - the four asymmetric fault debouncers and the three
#                   symmetric SPI filters alike.
#
#                   Qualification latency is ASSERT_CLKS or RELEASE_CLKS
#                   edges of continuous disagreement, counted from the first
#                   disagreeing edge. Groups 3 and 4 are the lower and upper
#                   bounds on that latency and only pin it exactly when taken
#                   together.
#
#                   hold_count is computed here from flag_in alone, rather
#                   than mirroring the DUT's disagree_counter, so that a bug
#                   in that counter does not appear identically in the checker
#                   and cancel out. It reads one below the number of edges
#                   held - see its own comment - so every property adds one
#                   before comparing against a target.
#
#                   Group 5 deliberately reads the DUT's own disagree_counter.
#                   The restart is unobservable at the ports, since flag_out
#                   does not move during a glitch, and the counter is named in
#                   input_debounce's header, so it is part of the contract
#                   rather than an implementation detail. Asserting against
#                   this checker's hold_count instead would only test the
#                   checker.


# Global variables: None

*/

`default_nettype none

module input_debounce_sva #(
    
    parameter int ASSERT_CLKS  = pmic_types_pkg::DEBOUNCE_ASSERT_CLKS,
    parameter int RELEASE_CLKS = pmic_types_pkg::DEBOUNCE_RELEASE_CLKS,
    parameter bit RESET_VALUE  = 1'b1
    
)(
    input  wire logic clk,
    input  wire logic rst_n,
    input  wire logic flag_in,     // synchronised comparator flag
    input  wire logic flag_out,     // debounced flag to the supervisor
    input  wire logic [CNT_W-1:0] dut_disagree_counter   // DUT internal, see header
);

localparam int CNT_MAX = (ASSERT_CLKS > RELEASE_CLKS) ? ASSERT_CLKS : RELEASE_CLKS;
localparam int CNT_W   = $clog2(CNT_MAX + 1);

// hold_count: edges flag_in has continuously disagreed with flag_out,
//             restarting on agreement
logic [CNT_W-1:0] hold_count;

always_ff @(posedge clk or negedge rst_n) begin
  /*
  Purpose:
  ---
  Measures the qualification window independently of the DUT's own
  disagree_counter, so a fencepost bug in that counter does not appear
  identically here and cancel out in the check. The restart condition is the
  same - it has to be, since the claim is about the disagreement window - but
  this one saturates at CNT_MAX and the properties compare against
  qual_target, where the DUT saturates one below its target and compares
  there. An off-by-one on either side therefore still shows.

  Entering edge k of a window this reads k-1, because the write lands after
  the edge while the properties sample before it. Every property adds one
  before comparing against a target.
  */
  if (!rst_n) begin

    hold_count <= '0;

  end

  else begin

    if (flag_in == flag_out)                hold_count <= '0;
    else if (hold_count != CNT_W'(CNT_MAX)) hold_count <= hold_count + 1'b1;
    // else: saturated and still disagreeing - hold

  end
  
end

// clks_since_release:    edges since rst_n was released, saturating at 1.
    //                     $changed(flag_out) at the first edge after release
    //                     compares against an edge inside reset, where the
    //                     value was driven by the async clear rather than by a
    //                     qualified transition. disable iff does not cover that
    //                     edge, since rst_n is already high there.
    logic clks_since_release;

    always_ff @(posedge clk or negedge rst_n) begin

      /*
      Purpose:
      ---
      Blanks the single edge after reset release. Properties using $changed or
      $stable reach one edge back, and at the first edge after release that
      reaches into reset, where flag_out was driven by the async clear rather
      than by a qualified transition - so the antecedent can fire with no
      window behind it. disable iff does not cover that edge, because rst_n is
      already high there. One bit is enough: the gate is needed once per
      release, not for a span of edges.
      */

        if (!rst_n)  clks_since_release <= 1'b0;
        else         clks_since_release <= 1'b1;
    end



/*
Purpose: PAC(Property, Assertion, Cover) Group 1: 
         Flag out never changes on a clock flag in still agrees with it
         
*/

property p_flag_out_faithful;

  @(posedge clk) disable iff (!rst_n)
    (flag_out == flag_in) |=> $stable(flag_out);

endproperty

a_flag_out_faithful: assert property (p_flag_out_faithful)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_flag_out_faithful: flag_out changed to %b while flag_in agreed at %b",flag_out, $past(flag_in)));

  end

c_flag_out_faithful: cover property (@(posedge clk) disable iff (!rst_n) flag_out == flag_in);

/*
////////////////////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2: 
         flag Out takes Reset value on reset assertion
         
*/

property p_flag_out_takes_RESET;

  @(posedge clk) 
    (!rst_n) |-> (flag_out == RESET_VALUE);

endproperty

a_flag_out_takes_RESET: assert property (p_flag_out_takes_RESET)

  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_flag_out_takes_RESET: flag_out took value = %b while it should have taken %b",flag_out, RESET_VALUE));

  end

c_flag_out_takes_RESET: cover property (@(posedge clk) !rst_n);

/*
//////////////////////////////////////////////////////////////////////////////////////////////
*/


/*
Purpose: PAC(Property, Assertion, Cover) Group 3:
         LOWER BOUND. flag_out never changes unless flag_in had disagreed with
         it for at least the qualification time - no transition without an
         earned window. Gated on clks_since_release because $changed reaches
         one edge back, and at the first edge after release that reaches into
         reset, where flag_out was driven by the async clear rather than by a
         qualified transition.
*/

// qual_target: qualification time for whichever transition just completed,
//              selected from flag_in because flag_out has taken its value
logic [CNT_W-1:0] qual_target;
assign qual_target = flag_in ? CNT_W'(ASSERT_CLKS) : CNT_W'(RELEASE_CLKS);

property p_flag_out_qualified;

  @(posedge clk) disable iff (!rst_n)
    (clks_since_release && $changed(flag_out)) |-> ((hold_count + 1'b1) >= qual_target);

endproperty

a_flag_out_qualified: assert property (p_flag_out_qualified)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_flag_out_qualified: flag_out changed to %b with hold_count=%0d, target=%0d",
       flag_out, hold_count + 1'b1, qual_target));

  end

c_flag_out_qualified: cover property (@(posedge clk) disable iff (!rst_n)
                          clks_since_release && $changed(flag_out));

/*
//////////////////////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4:
         UPPER BOUND. A window that completes DOES produce the transition, on
         the next edge - the complement of group 3. Without it a DUT whose
         output never moved at all would satisfy every other property here.
         Equality on the target rather than >=, so the check fires at the one
         edge the transition is owed; hold_count saturates, so >= would demand
         a change on every later edge too.

*/
property p_ASSERT_and_RELEASE_work;

  @(posedge clk) disable iff (!rst_n)
    (flag_out != flag_in) && clks_since_release && ((hold_count + 1'b1) == qual_target)
    |=> ($stable(flag_in) -> (flag_out == flag_in));
    
endproperty

a_ASSERT_and_RELEASE_work: assert property (p_ASSERT_and_RELEASE_work)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_ASSERT_and_RELEASE_work: window completed at hold_count=%0d target=%0d, but flag_out=%b did not follow flag_in=%b",
       $past(hold_count) + 1'b1, $past(qual_target), flag_out, flag_in));

  end

c_ASSERT_works:  cover property (@(posedge clk) disable iff (!rst_n)
                      clks_since_release && flag_in && (flag_in != flag_out)
                      && ((hold_count + 1'b1) == qual_target));

c_RELEASE_works: cover property (@(posedge clk) disable iff (!rst_n)
                      clks_since_release && !flag_in && (flag_in != flag_out)
                      && ((hold_count + 1'b1) == qual_target));




/*
/////////////////////////////////////////////////////////////////////////////////////////////////
*/


/*
Purpose: PAC(Property, Assertion, Cover) Group 5:
         A glitch part-way through a window restarts the count from zero
         rather than pausing it. A DUT that froze its counter on agreement
         would pass groups 1 to 4 - windows would still complete at the right
         count, just occasionally stretched - so this is the only property
         that catches it. hold_count > 1 restricts the match to windows with
         something to lose; a single disagreeing edge that reverses never
         started one.

         c_window_abandoned is the evidence the directed glitch scenario
         actually landed. 
*/

sequence s_window_abandoned;
    (flag_in != flag_out) && (hold_count > 1) ##1 (flag_in == flag_out);
endsequence

property p_window_abandoned;

  //disagree counter is the internal signal of the DUT, checking against this module's counter
  // is akin to not writing this PAC group at all
  @(posedge clk) disable iff (!rst_n)
    s_window_abandoned |=> (dut_disagree_counter == 0); 

endproperty

a_window_abandoned: assert property (p_window_abandoned)
  else begin
    
    sva_pkg::note_failure($sformatf(
      "a_window_abandoned: a glitch did not clear the counter - disagree_counter=%0d flag_in=%b, flag_out=%b",
       dut_disagree_counter, flag_in, flag_out));

  end

c_window_abandoned: cover property (@(posedge clk) disable iff (!rst_n)
                                        s_window_abandoned);

/*
//////////////////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

