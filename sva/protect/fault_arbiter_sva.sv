/*

# Filename:         fault_arbiter_sva.sv

# File Description: Skeleton for a bound SVA checker. Copy to
#                   sva/<group>/<module>_sva.sv - or run
#                   `make new_sva M=<group>/<module>` from sim/, which also
#                   copies the DUT's parameters and ports in - then state the
#                   module's contract and write one PAC group per claim.
#
#                   Attached with bind (sva/bind_sva.sv), so the RTL source
#                   carries no assertion constructs and the sv2v / yosys ASIC
#                   path never sees them. Every *.sv under sva/<group>/ is
#                   compiled into every testbench; this file sits at the top
#                   of sva/ and is not.
#
#                   House rules, from the existing checkers:
#                     - Claims come from the module HEADER, not its body. A
#                       checker that re-derives the implementation repeats its
#                       bugs and cancels them out.
#                     - Measure time with the checker's own aux counters where
#                       possible; read a DUT internal only through a dut_
#                       port, connected by name in the bind.
#                     - Every assertion reports through
#                       sva_pkg::note_failure(), never $error: Verilator's
#                       runtime error limit is 1 and would end the run.
#                     - Every assertion has at least one cover proving its
#                       antecedent happened. A zero-hit cover reads
#                       INCONCLUSIVE, and fails CI under STRICT=1.
#                     - disable iff (!rst_n) unless reset itself is the
#                       subject of the claim - say so in the Purpose block.
#
#                   Every <ANGLE_BRACKET> marker is a place to edit. A
#                   generated checker compiles as it stands, with its example
#                   group commented out, so creating one never breaks the
#                   other testbenches; it does nothing until it is bound.

# Global variables: None

*/

`default_nettype none

module fault_arbiter_sva
#(
    parameter int WINDOW_RUN = pmic_types_pkg::WINDOW_RUN,
    parameter int WINDOW_SS = pmic_types_pkg::WINDOW_SS,
    parameter int BLANK_CLKS = 5
)(
    input  wire logic                              clk,
    input  wire logic                              rst_n,
    input  wire logic                              pwm_sync,
    input  wire logic                              cp_sync,
    input  wire logic                              ss_active,
    input  wire logic                              run_active,
    input  wire logic [pmic_types_pkg::TRIP_W-1:0] trip_run,
    input  wire logic [pmic_types_pkg::TRIP_W-1:0] trip_ss,
    input  wire logic                              window_trip,  // DUT output
    input  wire logic                              window_trip_SS,  // DUT output
    input  wire logic [$clog2(WINDOW_RUN+1)-1:0]   fault_count_run_out,  // DUT output
    input  wire logic [$clog2(WINDOW_SS+1)-1:0]    fault_count_ss_out  // DUT output
    // DUT internals - connect each by name in the bind, e.g.
    //   .dut_<signal>(<signal>)
    // input  wire logic dut_<signal>
);


// <aux_signal>: <one line - what the checker tracks for itself, and why>
// logic <aux_signal>;

// always_ff @(posedge clk or negedge rst_n) begin
//   /*
//   Purpose:
//   ---
//   <The checker's own measure of the quantity under test, independent of the
//   DUT's implementation of it.>
//   */
//   if (!rst_n) begin
//     <aux_signal> <= '0;
//   end
//   else begin
//     <aux_signal> <= <next value>;
//   end
// end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1:
         <The claim, in one sentence, as the module header states it.>

         <Why this antecedent and implication; what a wrong DUT would do to
         fail it; why one cover or several.>

         The group is commented out so this file compiles as generated: every
         checker under sva/<group>/ is built into every testbench, so an
         unfinished placeholder would break all of them. Uncomment and fill in.
*/

// property p_<claim>;
//
//   @(posedge clk) disable iff (!rst_n)
//     <antecedent> |-> <consequent>;
//
// endproperty
//
// a_<claim>: assert property (p_<claim>)
//   else begin
//
//     sva_pkg::note_failure($sformatf(
//       "a_<claim>: <what was seen, with the values that matter>"));
//
//   end
//
// c_<claim>: cover property (@(posedge clk) disable iff (!rst_n) <antecedent>);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2:
         <Next claim. Copy the group above for each one.>
*/

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: Directed-scenario covers. No assertion of their own - the groups
         above state what must hold - but each is the evidence that the
         testbench actually built the case.

         c_<scenario>: <the corner the testbench must reach>
*/

// c_<scenario>: cover property (@(posedge clk) disable iff (!rst_n) <condition>);

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire
