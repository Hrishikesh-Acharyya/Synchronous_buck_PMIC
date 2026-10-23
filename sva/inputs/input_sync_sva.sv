/*

# Filename:         input_sync_sva.sv

# File Description: Concurrent assertion checker for input_sync. Attached with
#                   bind so the RTL source carries no assertion constructs and
#                   the sv2v / Yosys ASIC path never sees them. RESET_VALUE is
#                   passed through from the bound instance so each call site is
#                   checked against its own reset level.

# Global variables: None

*/

`default_nettype none

module input_sync_sva #(
 
    parameter logic RESET_VALUE = 1'b0
) (
    input  wire logic clk,
    input  wire logic rst_n,
    input  wire logic async_in,  
    input  wire logic sync_out
);

logic [1:0] clocks_after_reset_release;

always_ff @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin

        clocks_after_reset_release <= 2'b00;

    end

    else begin
        
        if(&clocks_after_reset_release) begin

            clocks_after_reset_release <= clocks_after_reset_release;

        end

        else begin

            clocks_after_reset_release <= clocks_after_reset_release + 1'b1;

        end

    end


end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1: 
         Confirm that sync_out reads the reset value when reset is active.
         
*/

property p_sync_out_reads_RESET;

    @(posedge clk)
        !rst_n |-> (sync_out == RESET_VALUE);
endproperty

a_sync_out_reads_RESET: assert property (p_sync_out_reads_RESET)
    else begin

        sva_pkg::note_failure($sformatf(
        "a_sync_out_reads_RESET: sync_out=%b expected %b", sync_out, RESET_VALUE));

    end

// c_reset_active: confirms reset was actually entered. Without a hit here,
//                 a_sync_out_reads_RESET never evaluated and its pass is
//                 vacuous.
c_reset_active: cover property (@(posedge clk) !rst_n);

/*
 //////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2: 
         Confirm that sync_out reads the async_in with 2 clock latency after waiting atleast
         two clocks after reset is released. Checks the 2 clock synchronizer working

*/

property p_two_clock_latency;

    @(posedge clk)
        clocks_after_reset_release >= 2'd2 |-> (sync_out == $past(async_in,2'd2));

endproperty

a_two_clock_latency: assert property (p_two_clock_latency)
    else begin

        sva_pkg::note_failure($sformatf(
        "a_two_clock_latency: sync_out=%b expected %b", sync_out, $past(async_in,2)));

    end

c_two_clock_latency_and_input_rose: cover property (@(posedge clk)
                  (clocks_after_reset_release >= 2'd2) && $rose(async_in));

c_two_clock_latency_and_input_fell: cover property (@(posedge clk)
                  (clocks_after_reset_release >= 2'd2) && $fell(async_in));


/*
//////////////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3: 
         Confirm that sync_out still reads the reset value one clock after release
         
*/

property p_one_clock_after_release;

    @(posedge clk)
        (clocks_after_reset_release == 2'd1) |-> (sync_out == RESET_VALUE);

endproperty

a_one_clock_after_release: assert property (p_one_clock_after_release)
    else begin

        sva_pkg::note_failure($sformatf(
         "a_one_clock_after_release: sync_out=%b expected %b", sync_out, RESET_VALUE)); 
    
    end

c_one_clock_after_release: cover property (@(posedge clk) clocks_after_reset_release == 2'd1);

/*
////////////////////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire






