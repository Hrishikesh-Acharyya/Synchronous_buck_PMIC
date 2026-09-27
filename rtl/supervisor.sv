module supervisor (input logic clk,
                   input logic SS_done,
                   input logic rst_n,
                   input logic g_en,
                   input logic latch_state,
                   input logic OTP,
                   input logic window_trip_SS,
                   input logic window_trip,
                   input logic latch_assert,
                   input logic UVLO,
                   input logic hiccup_done,
                   output logic en,
                   output logic ss_active,
                   output logic run_active,
                   output logic hiccup_active);
  
  import pmic_types_pkg::*;
  
  logic en_from_state;
  state_t state, next_state;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_OFF;
    else
        state <= next_state;
	end
  
  
  always_comb
    begin
      next_state = state;
      
        unique case(state)

        /*
        Go to next state only when g_en is high, not latched and no OTP fault.
        Otherwise stay in S_OFF. Start-up is additionally inhibited by latch_assert,
        so a strike-latched part cannot restart before the latch is read back on
        latch_state.
        */
          
				S_OFF: begin
					if (g_en & ~latch_state & ~OTP & ~UVLO & ~latch_assert)
						next_state = S_SS;
					else
						next_state = S_OFF;

			end

          /*
          if g_en is pulled low, or OTP or latched state goes high go back to S_OFF. 
          if too many faults during soft start(shift register check) then go to HICCUP
          if Soft starting completed then go to S_RUN
          We dont worry about OVP as any latching is immediately seen by latch_state

          The final else holds in S_SS rather than advancing: soft start must remain
          active until SS_done, otherwise the state lasts a single clock and the ramp
          is never awaited.
          */      
          
          S_SS: begin
            if(~g_en|OTP|latch_state|UVLO|latch_assert)
              next_state = S_OFF;

            else if (window_trip_SS)
              next_state = S_HICCUP;

            else if ( SS_done)
              next_state = S_RUN;
            
            else
              next_state = S_SS;

          end
          
          /*
          If g_en pulled low or latch on or OTP, then go back to S_OFF
          If window tripped then go to hiccuping
          No other faults then it should stay in S_RUN

          latch_assert is included so that state and output agree: the output gate below
          already forces en low on latch_assert, and without the state change the FSM
          would remain in S_RUN and re-enable at full duty when latch_assert released.
          */
     
          S_RUN: begin
            if(~g_en|latch_state|OTP|UVLO|latch_assert)
              next_state = S_OFF;
            else if (window_trip)
              next_state = S_HICCUP;
            else
              next_state = S_RUN;
            
     end
			 
          /* If g_en pulled low, OTP, latch_state or latch_assert, go back to S_OFF.
          Otherwise hold in S_HICCUP until hiccup_done: the cool-down must actually
          elapse before a retry.
          */

          S_HICCUP: begin

            if(~g_en|latch_state|OTP|latch_assert|UVLO)
              next_state = S_OFF;
            else if (hiccup_done)
              next_state = S_SS;
            else
              next_state = S_HICCUP;

          end   
      
        default: next_state= S_OFF;
/*
illegeal states turn the PMIC off. 
*/
        endcase
    end
 


always_comb 
    unique case (state)
        S_OFF:    en_from_state = 1'b0;
        S_SS:     en_from_state = 1'b1;
        S_RUN:    en_from_state = 1'b1;
        S_HICCUP: en_from_state = 1'b0;
        default:  en_from_state = 1'b0;
    endcase

always_comb ss_active  = (state == S_SS);
always_comb run_active = (state == S_RUN);
always_comb hiccup_active = (state == S_HICCUP);


always_comb
    en = en_from_state & ~OTP & ~latch_state & ~UVLO&~latch_assert;
      
              
        
              
           
endmodule
