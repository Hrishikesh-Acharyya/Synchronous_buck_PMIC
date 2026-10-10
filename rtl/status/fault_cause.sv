/*
# Filename:         fault_cause.sv

# File Description: Records WHICH fault conditions occurred during an episode of
#                   converter operation, as a one-hot vector that accumulates
#                   until the host reads it.
#
#                   Every fault input in this design is transient. OTP clears as
#                   the board cools, UVLO clears as Vin recovers, and window_trip
#                   is a combinational comparison on a rolling window that resets
#                   the moment the supervisor leaves S_RUN. So by the time anyone
#                   asks why the converter shut down, the condition that caused it
#                   is usually gone. This module stores history to tell what went
#                   wrong after the fact.
#
#                   Priority is encoded in bit position, MSB highest.
#
#                   OVP is INFERRED, not measured. The shared protection latch has
#                   exactly two trip sources - the analog OVP comparator and the
#                   CPLD's own latch_out, driven by latch_assert - and an
#                   overcurrent reaches it only through the digital window, strikes
#                   and latch_assert. So latch_assert is always already high on a
#                   CPLD-originated trip, and latch_state high with latch_assert low
#                   isolates an analog-origin trip. This holds only because
#                   rst_n_pin is wired to the latch's manual drain button, so the
#                   SCR and latch_assert always clear together.
#
#                   LIMITATIONS:
#                   - No ordering or repetition is preserved. OTP-then-OCP reads
#                     identically to OCP-then-OTP, and a cause that recurred reads
#                     the same as one that happened once. fault_log fills that gap.
#                   - A fault asserting while the converter is already stopped is
#                     not captured. The register means "faults that interrupted
#                     operation", not "conditions that were ever true".
#
#                   Telemetry only. Drives no control path and takes no part in any
#                   protection decision; removing this module leaves the converter
#                   functionally identical.

# Global variables: None

*/

`default_nettype none

module fault_cause
    import pmic_types_pkg::*;
(
    input  wire logic clk,
    input  wire logic rst_n,

    // ---- live fault conditions, all already synchronised and debounced ----
    input  wire logic otp_state,       // debounced OTP comparator
    input  wire logic uvlo_state,      // debounced input UVLO comparator
    input  wire logic latch_state,     // debounced SCR readback
    input  wire logic latch_assert,    // CPLD's own trip into the latch
    input  wire logic window_trip,     // overcurrent window exceeded in S_RUN
    input  wire logic window_trip_SS,  // overcurrent window exceeded in S_RUN

    // ---- episode scoping ----
    input  wire logic ss_active,
    input  wire logic run_active,
    input  wire logic fault_reg_read_done, // one-clk pulse from reg_file

    //fault_reg:  Keeps state of the faults that have occured,
    //            1- hot encoded and OR-accumulated.
    //            [10000] - OVP
    //            [01000] - LATCH_ASSERT (OCP/SCP)
    //            [00100] - OTP
    //            [00010] - UVLO
    //            [00001] - OVERCURRENT -> WINDOW_TRIP/WINDOW_SS FIRED
    output logic [FAULT_CAUSE_W-1:0] fault_reg
);
// Bit positions in fault_reg. MSB-first is priority order.
localparam int BIT_OVP   = 4;
localparam int BIT_LATCH = 3;
localparam int BIT_OTP   = 2;
localparam int BIT_UVLO  = 1;
localparam int BIT_OC    = 0;

logic  convertor_running;
logic  ovp;

/*
Purpose:
---
Capture gate. Faults are recorded only while the converter is actually running,
so a normal power-down - which drops Vin and asserts UVLO while the housekeeping
rail still holds the CPLD up - does not log a fault for every routine shutdown.

*/
always_comb convertor_running = (ss_active||run_active);

always_comb begin

/*
Purpose:
---
Infer an analog overvoltage trip. The protection latch is shared between the
analog OVP comparator and the CPLD, and only the CPLD's own trips are preceded by
latch_assert, so the latch reading back set with latch_assert clear means the
analog side tripped it. See the file header for why no other condition produces
this combination.
*/

  if(latch_state & ~latch_assert) ovp = 1'b1;
  else ovp = 1'b0;

end

always_ff @ (posedge clk or negedge rst_n) begin

  /*
Purpose:
---
Accumulate causes across an episode and clear when the host reads the register.
Bits are set, never cleared individually, so a fault that has since gone away is
still reported.

Clear-on-read makes the register mean "faults since you last asked", which is the
question firmware is actually asking. It also self-corrects: a fault still live
after a read re-sets its own bit on the next clock, so the register cannot go
stale while something is genuinely wrong.

The clear branch takes priority over capture, so a read landing on the same clock
as a new cause starts a clean interval. Nothing is lost - if that cause is still
asserted it is captured again immediately.

*/

  if(!rst_n) begin

    fault_reg <= '0;

  end

  //clear on host read of fault reg
  else if (fault_reg_read_done) begin

    fault_reg <= '0;

  end

  else if(convertor_running) begin

    if(otp_state)                       fault_reg[BIT_OTP]   <= 1'b1;
    if(uvlo_state)                      fault_reg[BIT_UVLO]  <= 1'b1;
    if(window_trip || window_trip_SS)   fault_reg [BIT_OC]   <= 1'b1;
    if(ovp)                             fault_reg[BIT_OVP]   <= 1'b1;
    if(latch_assert)                    fault_reg[BIT_LATCH] <= 1'b1;

  end

end

endmodule
`default_nettype  wire

