module supervisor (input clk,
                   input SS_done,
                   input rst_n,
                   input g_en,
                   input latch_state,
                   input OTP,
                   input window_trip_SS,
                   input window_trip,
                   input latch_assert,
                   input UVLO,
                   output reg en);
  
  reg [1:0] state,next_state;
  reg en_from_state;
  localparam S_OFF = 2'b0,S_SS = 2'b1, S_RUN = 2'b10, S_HICCUP = 2'b11;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_OFF;
    else
        state <= next_state;
	end
  
  
  always @(*)
    begin
      next_state = state;
      
        case(state)
          
          S_OFF: next_state = (g_en&~latch_state&~OTP&~UVLO&~latch_assert)?S_SS:S_OFF; 
/*
Go to next state only when g_en is high, npt latched and no OTP Fault. Otherwise stay as S_OFF is  default
FIX: added ~latch_assert. If the strike counter has latched us off, we must not
start up again just because the latch has not been read back yet.
 */
          
          S_SS: begin
            if(~g_en|OTP|latch_state|UVLO|latch_assert)
              next_state = S_OFF;
            else if ( SS_done)
              next_state = S_RUN;
            else if (window_trip_SS)
              next_state = S_HICCUP;
            else
              next_state = S_SS;
/*
if g_en is pulled low, or OTP or latched state goes high go back to S_OFF. 
if Soft starting completed then go to S_RUN
if too many faults during soft start(shift register check) then go to HICCUP
We dont worry about OVP as any latching is immediately seen by latch_state

FIX 1: the last else was S_RUN. That meant "soft start is NOT done and nothing
is wrong -> go to RUN anyway", so S_SS only ever lasted one clock and the ramp
was never actually waited for. It must stay in S_SS until SS_done.

FIX 2: added latch_assert to the shutdown condition above. It was only tested
in S_HICCUP, so a strike latch during soft start did not stop the FSM.
*/
          end
          
          
          S_RUN: begin
            if(~g_en|latch_state|OTP|UVLO|latch_assert)
              next_state = S_OFF;
            else if (window_trip)
              next_state = S_HICCUP;
            else
              next_state = S_RUN;
            
/*
If g_en pulled low or latch on or OTP, then go back to S_OFF
If window tripped then go to hiccuping
No other faults then it should stay in S_RUN

FIX 2: added latch_assert here too. Without it, asserting latch_assert while
running left the FSM sitting in S_RUN with en forced low by the output gate
below. When latch_assert released, en went straight back high at full duty
with no soft start. State and output disagreed.
*/
          end
          
          
          
          
          S_HICCUP: begin
            if(~g_en|latch_state|OTP|latch_assert|UVLO)
              next_state = S_OFF;
            else 
              next_state = S_SS;
            
            
/*
if g_en pulled low or OTP event or latch pulled then go back to S_OFF
or if due to this hiccup state, strike was fulfilled then assert latch and go back to S_OFF
If all good, go back to S_SS not S_OFF as no point in staying there and wasting a cycle
*/
          end   
      
        default: next_state= S_OFF;
/*
illegeal states turn the PMIC off. 
*/
        endcase
    end
 


always @(*)
    case (state)
        S_OFF:    en_from_state = 1'b0;
        S_SS:     en_from_state = 1'b1;
        S_RUN:    en_from_state = 1'b1;
        S_HICCUP: en_from_state = 1'b0;
        default:  en_from_state = 1'b0;
    endcase

always @(*)
    en = en_from_state & ~OTP & ~latch_state & ~UVLO&~latch_assert;
      
              
        
              
           
endmodule
