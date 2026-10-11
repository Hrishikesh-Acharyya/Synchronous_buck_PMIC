/*

# Filename:         timestamp.sv

# File Description: Free-running millisecond counter. Sole purpose is to supply a
#                   timestamp to the fault log, so an entry records WHEN a cause
#                   occurred and not merely that it did.
#
#                   Counts milliseconds rather than switching cycles, which was the
#                   alternative. A switching-cycle count stops advancing in S_HICCUP
#                   and S_LATCHED, because the power stage is disabled and there are
#                   no cycle boundaries - precisely the states in which elapsed time
#                   is most worth knowing. It would also wrap in about 37 seconds at
#                   450 kHz over TIMESTAMP_W bits, against 4.66 hours here.
#
#                   The counter free-runs in every supervisor state and wraps
#                   naturally; it is cleared only by rst_n. A host reading a
#                   timestamp older than one wrap period cannot distinguish it from a
#                   recent one, which is a documented limitation rather than a bug -
#                   the fault log is read during a debug session, not weeks later.
#
#                   Telemetry only. Drives no control path; removing this module
#                   leaves the converter functionally identical.

# Global variables: None

*/



`default_nettype none

module timestamp
import pmic_types_pkg::*;

                
                  (
                     input  wire logic clk,
                     input  wire logic  rst_n,
                     //timestamp_ms: the timsetamp counter
                     output logic [TIMESTAMP_W-1:0] timestamp_ms
                  );

//prescalar: the prescalar counter, counts PRESCALE_VAL times, to indicate required time elapsed
logic [PRESCALAR_W - 1:0] prescalar;
//PRESCALE_VAL: Derived from the clock frequency and the required timestamp unit encoded as PRESCALAR_HZ


always_ff @ (posedge clk or negedge rst_n) begin

  /*
  Purpose:
  ---
  Divide the system clock down to a 1 ms tick. 
  */
  if(!rst_n) begin

    prescalar <= '0;

  end

  else begin

    if(prescalar == PRESCALE_VAL-1) begin

        prescalar <= '0;

    end

    else begin

       prescalar <= prescalar + 1'b1;

    end

  end

end
  
always_ff @ (posedge clk or negedge rst_n) begin

  /*
Purpose:
---
Accumulate milliseconds. Increments once per prescaler wrap and never resets on a
fault, a state change, or a host read..

Wraps silently at 2**TIMESTAMP_W.
*/

  if(!rst_n) begin

    timestamp_ms <= '0;

  end

  else begin

    if(prescalar == PRESCALE_VAL-1) timestamp_ms <= timestamp_ms + 1'b1;

  end

end


endmodule

`default_nettype wire


