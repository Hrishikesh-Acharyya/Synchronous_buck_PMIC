/*

# Filename:         reg_file.sv

# File Description: Transport-agnostic register map for the PMIC supervisor. Presents a
#                   byte-addressable view of supervisor status to a host, and holds the
#                   writable control bits and protection thresholds..

# Global variables: None

*/

`default_nettype none

module reg_file
    import pmic_types_pkg::*;

#(
    // PMIC_ID: fixed identifier byte; lets the host confirm it is talking to this
    //              device rather than another slave answering on the same select
    parameter logic [7:0] PMIC_ID     = 8'hB5,

    // VERSION_ID: {major[3:0], minor[3:0]} revision of the REGISTER MAP, not the RTL.
    //              Bump it when an address changes meaning, so firmware can refuse a
    //              map it does not understand
    parameter logic [7:0] VERSION_ID     = 8'h01,

    // DISABLE_KEY_ID: magic byte arming a host-commanded disable
    parameter logic [7:0] DISABLE_KEY_ID = 8'hD1,

    // WRITE_ACCESS_KEY_ID: magic byte unlocking the threshold bank
    parameter logic [7:0] WRITE_ACCESS_KEY_ID  = 8'hA7,

    // ARM_TIMEOUT_W: width of the arm expiry counter. At 50 MHz, 16 bits is about
    //                1.3 ms - far longer than any legal transaction, far shorter
    //                than a human notices.
    parameter int ARM_TIMEOUT_W = 16
)
(
    input  wire logic clk,
    input  wire logic rst_n,

    // ---- host access port (transport agnostic) ----

    //addr: 7 bit address
    input wire logic [6:0] addr,
    // wr_en: Indicates write command
    input wire logic wr_en,
    // wdata: host -> supervisor. Data that is to be written into supervisor by MCU
    input wire logic [7:0] wdata,
    // rdata: supervisor -> host. Data that supervisor gives
    output logic [7:0] rdata,
    // rd_first : first data byte of a read  -> triggers snapshot

    /* verilator lint_off UNUSEDSIGNAL */
    input wire logic rd_first,   // unused until cycle_count / bus_err_count exist
    /* verilator lint_on UNUSEDSIGNAL */

    // integrity_OK   : write transaction passed length check and CRC
    input wire logic integrity_OK,
    // abort    : transaction ended unvalidated -> discard temporary flop data. 
    input wire logic abort,

    // ---- status in (read path sources) ----
    
    // sup_state: supervisor FSM state. Telemetry, and ALSO the gate on hiccup_base and
    //            cycles_per_step writes - those are only accepted in S_OFF
    input wire state_t sup_state,
    input wire logic pgood,
    input wire logic latch_state,
    input wire logic en_switch,
    input wire logic en_switch_rise,
    input wire logic cp_state,
    input wire logic otp_state,
    input wire logic uvlo_state,
    input wire logic [STRIKE_W-1:0] strike_level,
    input wire logic [CNT_W-1:0] duty_count,
    input wire logic [CNT_W-1:0] prev_period,
    input wire logic [4:0] fault_count_run,
    input wire logic [5:0] fault_count_ss,

    //@TODO: These telemetey are to be written as modules

    // peak_fault_run: highest value fault_count_run has reached since reset; shows how
    //                 close to TRIP_RUN the board normally runs
    input  wire logic [4:0]          peak_fault_run,
    // cycle_count:    free-running switching-cycle count; timestamp source for the fault log
    input  wire logic [23:0]         cycle_count,
    // bus_err_count:  CRC failures, CS timeouts and misaligned transactions seen by
    //                 spi_slave; a healthy link leaves this at zero
    input  wire logic [15:0]         bus_err_count,

    // ---------------- fault log ----------------

    // log_index: host writes which fault-log entry it wants; drives the log's read port
    output logic      [3:0]          log_index,
    // log_entry: the selected entry, returned through the 0x70/0x71 data window
    input  wire logic [15:0]         log_entry,


    // ---------------- control out ----------------
    // What registers the MCU can write
    output logic                     spi_enable,
    output logic [TRIP_W-1:0]        trip_run,
    output logic [TRIP_W-1:0]        trip_ss,
    output logic [STRIKE_W-1:0]      max_strikes,
    output logic [ON_TIME_W-1:0]     max_on_limit,

    // ---------------- thresholds writable only in S_OFF ----------------
  
     // hiccup_base: strike-level-0 cool-down in clk counts, not milliseconds
    output logic [HICCUP_BASE_W-1:0] hiccup_base,
    // cycles_per_step: switching cycles per soft-start ramp step
    output logic [CYC_STEP_W-1:0]               cycles_per_step,
    // clean_run_target: fault-free switching cycles in S_RUN that clear the
    //                   strike count
    output logic [CLEAN_RUN_W-1:0]   clean_run_target  
);

    logic write_rejected;   // set when a threshold write is refused (locked, or not in S_OFF)


    // ---- 0x00-0x0F : identity ----
    localparam logic [6:0] ADDR_PMIC_ID      = 7'h00;
    localparam logic [6:0] ADDR_VERSION      = 7'h01;
    localparam logic [6:0] ADDR_CAPABILITY   = 7'h02;
    localparam logic [6:0] ADDR_SCRATCH      = 7'h03;

     // ---- 0x10-0x3F : telemetry, read only ----
    localparam logic [6:0] ADDR_STATUS       = 7'h10;
    localparam logic [6:0] ADDR_FAULT_FLAGS  = 7'h11;
    localparam logic [6:0] ADDR_STRIKE_LEVEL = 7'h12;
    localparam logic [6:0] ADDR_DUTY_COUNT   = 7'h13;
    localparam logic [6:0] ADDR_PREV_PERIOD  = 7'h14;
    localparam logic [6:0] ADDR_FCOUNT_RUN   = 7'h15;
    localparam logic [6:0] ADDR_FCOUNT_SS    = 7'h16;
    localparam logic [6:0] ADDR_PEAK_FRUN    = 7'h17;
    localparam logic [6:0] ADDR_CYCLE_0      = 7'h18;
    localparam logic [6:0] ADDR_CYCLE_1      = 7'h19;
    localparam logic [6:0] ADDR_CYCLE_2      = 7'h1A;
    localparam logic [6:0] ADDR_BUS_ERR_L    = 7'h1B;
    localparam logic [6:0] ADDR_BUS_ERR_H    = 7'h1C;

    // ---- 0x40-0x4F : control ----
    // DISABLE_KEY sits directly below CONTROL so auto-increment carries the arm
    // and the command inside one transaction, under one CRC.
    localparam logic [6:0] ADDR_DISABLE_KEY  = 7'h40;
    localparam logic [6:0] ADDR_CONTROL      = 7'h41;
    localparam logic [6:0] ADDR_LOG_INDEX    = 7'h42;
    // WRITE_ACCESS_KEY sits at the TOP of the bank for the same reason: the next
    // address after it is the first threshold.
    localparam logic [6:0] ADDR_WRITE_KEY    = 7'h4F;

      // ---- 0x50-0x6F : thresholds, locked ----
    localparam logic [6:0] ADDR_TRIP_RUN     = 7'h50;
    localparam logic [6:0] ADDR_TRIP_SS      = 7'h51;
    localparam logic [6:0] ADDR_MAX_STRIKES  = 7'h52;
    localparam logic [6:0] ADDR_MAX_ON       = 7'h53;
    localparam logic [6:0] ADDR_HICCUP_0     = 7'h54;
    localparam logic [6:0] ADDR_HICCUP_1     = 7'h55;
    localparam logic [6:0] ADDR_HICCUP_2     = 7'h56;
    localparam logic [6:0] ADDR_CYC_PER_STEP = 7'h57;
    localparam logic [6:0] ADDR_CLEAN_RUN_0  = 7'h58;
    localparam logic [6:0] ADDR_CLEAN_RUN_1  = 7'h59;
    localparam logic [6:0] ADDR_CLEAN_RUN_2  = 7'h5A;

    // ---- 0x70-0x71 : fault log data window ----
    localparam logic [6:0] ADDR_LOG_DATA_L   = 7'h70;
    localparam logic [6:0] ADDR_LOG_DATA_H   = 7'h71;

    // CAPABILITY_VAL: which optional blocks were compiled in. Lets one firmware
    // image serve several build configurations - the host reads this and knows
    // not to bother with addresses whose source does not exist yet.
    //   [0] pwm_stats present     [1] fault log present
    //   [2] thresholds writable   [3] peak fault tracking
    //   [4] cycle counter         [5] bus error counter
    localparam logic [7:0] CAPABILITY_VAL = 8'b0000_0101;


    // ==================================================================
    // Internal state
    // ==================================================================
    // scratch_r: read-write byte with no effect on anything. The host writes a
    //            pattern and reads it back to prove both bus directions work
    //            before trusting any real register.
    logic [7:0] scratch_r;
    // disable_armed: a valid DISABLE_KEY has been written; the next CONTROL write
    //                clearing bit 0 will be honoured
    logic       disable_armed;
    // unlock_armed: a valid WRITE_ACCESS_KEY has been written; the threshold bank
    //               will accept a commit
    logic       unlock_armed;
    // arm_timer: counts while either key is armed. An armed operation the host
    //            never follows through must lapse rather than sit armed forever -
    //            the MCU can be unplugged mid-sequence.
    logic [ARM_TIMEOUT_W-1:0] arm_timer;

    
    // Temporary registers: every threshold write lands here first and reaches the live
    // register only on integrity_OK. This is what stops a 3-byte hiccup_base from
    // spending a cycle half-written, which would be a momentarily nonsense cool-down.

    logic [7:0] temp_trip_run, temp_trip_ss, temp_max_strk, temp_max_on;
    logic [7:0] temp_hiccup_0, temp_hiccup_1, temp_hiccup_2;
    logic [7:0] temp_cyc_step;
    logic [7:0] temp_clean_0, temp_clean_1, temp_clean_2;

    // temp_dirty: one bit per temp register. Commit disturbs only what the
    //               host actually wrote in this transaction - a write touching
    //               TRIP_RUN must not also rewrite MAX_STRIKES from a stale temp.
    logic [10:0] temp_dirty;

    // en_pending / en_pending_val: a CONTROL write records its intent here rather
    // than changing spi_enable directly. The change applies only on integrity_OK,
    // so a transaction whose CRC fails cannot stop a running converter. The
    // thresholds already work this way; spi_enable is the one bit where getting it
    // wrong costs the load its power.
    logic en_pending;
    logic en_pending_val;



    // ==================================================================
    // Clamp functions - the range proved safe at design time
    // ==================================================================
    // These are the last line of defence. CRC catches corruption on the wire; the
    // clamp catches a bug at the source. No host write can place the hardware
    // outside these bounds, because out-of-range values SATURATE rather than being
    // rejected.
    //
    // Written with implicit result assignment rather than `return`, because the
    // ASIC path goes through sv2v and the stock Yosys frontend rejects `return`
    // inside a function.

    /* clamp_trip_run: saturate a run-window threshold. The window is WINDOW_RUN
       cycles deep, so a threshold above it could never be reached - that would
       silently disable overcurrent protection in S_RUN. */

    function automatic logic [TRIP_W-1:0] clamp_trip_run (input logic[7:0] input_trip_run);

      if(input_trip_run<8'd1)                 clamp_trip_run = TRIP_W'(1);
      else if (input_trip_run>8'(WINDOW_RUN)) clamp_trip_run = TRIP_W'(WINDOW_RUN);
      else                                    clamp_trip_run = input_trip_run[TRIP_W-1:0];

    endfunction

     /* clamp_trip_ss: the same for the deeper soft-start window */

     function automatic logic [TRIP_W-1:0] clamp_trip_ss (input logic [7:0] input_trip_ss);

      if      (input_trip_ss<8'd1)           clamp_trip_ss = TRIP_W'(1);
      else if (input_trip_ss>8'(WINDOW_RUN)) clamp_trip_ss = TRIP_W'(WINDOW_SS);
      else                                   clamp_trip_ss = input_trip_ss[TRIP_W-1:0];

     endfunction

     /* clamp_max_strikes: DOWNWARD ONLY. STRIKE_W and HICCUP_TIMER_W are both sized
       from MAX_STRIKES_DEFAULT, so raising it past the default would overflow
       strike_level and under-size the cool-down counter. */

       function automatic logic [STRIKE_W-1:0] clamp_max_strikes (input logic [7:0] input_max_strikes);

        if      (input_max_strikes < 8'd1)                    clamp_max_strikes = STRIKE_W'(1);
        else if (input_max_strikes > 8'(MAX_STRIKES_DEFAULT)) clamp_max_strikes = STRIKE_W'(MAX_STRIKES_DEFAULT);
        else                                                   clamp_max_strikes = input_max_strikes[STRIKE_W-1:0];

       endfunction

       /* clamp_max_on: DOWNWARD ONLY. Writing a duty ceiling above the compile-time
       default would stop the LM5106 bootstrap capacitor recharging during low-side
       conduction, collapsing high-side gate drive and destroying the FET. A single
       register write must never be able to do that. */

       function automatic logic [ON_TIME_W-1:0] clamp_max_on (input logic [7:0] input_max_on);

        if     (input_max_on > 8'(MAX_ON_COUNTS_DEFAULT)) clamp_max_on = ON_TIME_W'(MAX_ON_COUNTS_DEFAULT);
        else if(input_max_on< 8'(MIN_ON_COUNTS))          clamp_max_on = ON_TIME_W'(MIN_ON_COUNTS);
        else                                              clamp_max_on = input_max_on[ON_TIME_W-1:0];

       endfunction

       /* clamp_cyc_step: ramp rate. Zero would make the step condition never match. */

       function automatic logic [CYC_STEP_W-1:0] clamp_cyc_step (input logic [7:0] input_cyc_step);

        if      (input_cyc_step < 8'd1)                       clamp_cyc_step = CYC_STEP_W'(1);
        else if (input_cyc_step > 8'(CYCLES_PER_STEP_MAX))    clamp_cyc_step = CYC_STEP_W'(CYCLES_PER_STEP_MAX);
        else                                                  clamp_cyc_step = input_cyc_step[CYC_STEP_W-1:0];
       endfunction

       /* clamp_hiccup: cool-down base in clk counts. The upper bound is what
       HICCUP_TIMER_W was sized for; exceeding it would overflow the cool-down
       counter and end the interval early. */

       function automatic logic [HICCUP_BASE_W-1:0] clamp_hiccup (input [23:0] input_hiccup);

        if      (input_hiccup < 24'(HICCUP_BASE_MIN_CLKS)) clamp_hiccup = HICCUP_BASE_W'(HICCUP_BASE_MIN_CLKS);
        else if (input_hiccup > 24'(HICCUP_BASE_MAX_CLKS)) clamp_hiccup = HICCUP_BASE_W'(HICCUP_BASE_MAX_CLKS);
        else                                               clamp_hiccup = input_hiccup[HICCUP_BASE_W-1:0];

       endfunction

       /* clamp_clean_run: fault-free cycles that clear the strike count. Bounded above
       by the counter width in strike_counter. */

       function automatic logic [CLEAN_RUN_W-1:0] clamp_clean_run (input logic [23:0] raw);
        if      (raw < 24'(CLEAN_RUN_MIN_CYCLES))  clamp_clean_run = CLEAN_RUN_W'(CLEAN_RUN_MIN_CYCLES);
        else if (raw > 24'((2**CLEAN_RUN_W)-1))    clamp_clean_run = CLEAN_RUN_W'((2**CLEAN_RUN_W)-1);
        else                                       clamp_clean_run = raw[CLEAN_RUN_W-1:0];
       endfunction


    // ==================================================================
    // read multiplexer
    // ==================================================================
    always_comb begin
    /*
    Purpose:
    ---
    Present the addressed byte combinationally. Holds no state: a wide mux routing
    existing signals. Default assignment before the case prevents latches on
    unimplemented addresses, which return 0x00 by contract.
    */

    rdata = 8'h00;

    case(addr) 

      //identity
      ADDR_PMIC_ID    :  rdata = PMIC_ID;
      ADDR_VERSION    :  rdata = VERSION_ID;
      ADDR_CAPABILITY :  rdata = CAPABILITY_VAL;
      ADDR_SCRATCH    :  rdata = scratch_r;

      //telemetry

      // STATUS packs the whole machine state into one byte, so a host that
      // polls one address learns everything it needs about its own last
      // command as well as the converter.
      ADDR_STATUS     : rdata = {write_rejected,           // [7]
                                         disable_armed,    // [6]
                                         spi_enable,       // [5]
                                         en_switch,        // [4]
                                         latch_state,      // [3]
                                         pgood,            // [2]
                                         sup_state};       // [1:0]

      ADDR_FAULT_FLAGS :  rdata = {5'b0, cp_state, otp_state, uvlo_state};
      ADDR_STRIKE_LEVEL : rdata = 8'(strike_level);
      ADDR_DUTY_COUNT   : rdata = (duty_count);
      ADDR_PREV_PERIOD  : rdata = (prev_period);
      ADDR_FCOUNT_RUN   : rdata = 8'(fault_count_run);
      ADDR_FCOUNT_SS    : rdata = 8'(fault_count_ss);
      ADDR_PEAK_FRUN    : rdata = 8'(peak_fault_run);
      ADDR_CYCLE_0      : rdata = (cycle_count[7:0]);
      ADDR_CYCLE_1      : rdata = (cycle_count[15:8]);
      ADDR_CYCLE_2      : rdata = (cycle_count[23:16]);
      ADDR_BUS_ERR_L    : rdata = (bus_err_count[7:0]);
      ADDR_BUS_ERR_H    : rdata = (bus_err_count[15:8]);

      // ---- control readback ----
      // CONTROL reports REALITY, not intent: bit 0 is the live enable state.
      // An armed-but-not-executed disable shows separately in bit 1, so
      // firmware can tell "armed" from "disabled".

      ADDR_CONTROL : rdata = {5'b0, en_pending, disable_armed, spi_enable};
      ADDR_WRITE_KEY    : rdata = {7'b0, unlock_armed};
      ADDR_LOG_INDEX    : rdata = 8'(log_index);
      ADDR_DISABLE_KEY :  rdata = {7'b0, disable_armed};


      // ---- threshold readback: what is IN EFFECT, post-clamp ----

      ADDR_TRIP_RUN     : rdata = 8'(trip_run);
      ADDR_TRIP_SS      : rdata = 8'(trip_ss);
      ADDR_MAX_STRIKES  : rdata = 8'(max_strikes);
      ADDR_MAX_ON       : rdata = 8'(max_on_limit);
      ADDR_HICCUP_0     : rdata = hiccup_base[7:0];
      ADDR_HICCUP_1     : rdata = hiccup_base[15:8];
      ADDR_HICCUP_2     : rdata = 8'(hiccup_base[HICCUP_BASE_W-1:16]);
      ADDR_CYC_PER_STEP : rdata = 8'(cycles_per_step);
      ADDR_CLEAN_RUN_0  : rdata = clean_run_target[7:0];
      ADDR_CLEAN_RUN_1  : rdata = clean_run_target[15:8];
      ADDR_CLEAN_RUN_2  : rdata = 8'(clean_run_target[CLEAN_RUN_W-1:16]);

      // ---- fault log window ----
      ADDR_LOG_DATA_L   : rdata = log_entry[7:0];
      ADDR_LOG_DATA_H   : rdata = log_entry[15:8];

      default: rdata = 8'h00;


    endcase
    end


    // ==================================================================
    // write temp accumulation
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin

    /*
    Purpose:
    ---
    Accept threshold writes into temp storage only. NOTHING here reaches a live
    register; BLOCK 4 does that on integrity_OK.

    Writes are accepted regardless of unlock state. The unlock is checked at commit,
    not here, so the gating lives in exactly one place - and so a host that writes
    the threshold before the key still fails cleanly rather than half-succeeding.

    The dirty bits are cleared on BOTH transaction boundaries: discarded on abort,
    consumed on integrity_OK. Either way no temp survives into the next
    transaction, so a value written in one transaction cannot be committed by a
    later unrelated one.
    */

    if(!rst_n) begin

      temp_dirty    <= '0;
      temp_trip_run <= '0;
      temp_trip_ss  <= '0;
      temp_max_strk <= '0;
      temp_max_on   <= '0;
      temp_hiccup_0 <= '0;
      temp_hiccup_1 <= '0;
      temp_hiccup_2 <= '0;
      temp_cyc_step <= '0;
      temp_clean_0  <= '0;
      temp_clean_1  <= '0;
      temp_clean_2  <= '0;

    end

    else if (abort || integrity_OK) begin
      temp_dirty <= 0;
    end

    else if (wr_en) begin

        case(addr) 

          ADDR_TRIP_RUN: begin

            temp_trip_run <= wdata;
            temp_dirty[0] <= 1'b1;

          end

          ADDR_TRIP_SS: begin

            temp_trip_ss <= wdata;
            temp_dirty[1] <= 1'b1;

          end

          ADDR_MAX_STRIKES: begin

            temp_max_strk <= wdata;
            temp_dirty[2] <= 1'b1;

          end

          ADDR_MAX_ON: begin

            temp_max_on <= wdata;
            temp_dirty[3] <= 1'b1;

          end

          ADDR_HICCUP_0: begin

            temp_hiccup_0 <= wdata;
            temp_dirty[4] <= 1'b1;

          end

          ADDR_HICCUP_1: begin

            temp_hiccup_1 <= wdata;
            temp_dirty[5] <= 1'b1;

          end

          ADDR_HICCUP_2: begin

            temp_hiccup_2 <= wdata;
            temp_dirty[6] <= 1'b1;

          end

          ADDR_CYC_PER_STEP: begin

            temp_cyc_step <= wdata;
            temp_dirty[7] <= 1'b1;

          end

          ADDR_CLEAN_RUN_0: begin

            temp_clean_0 <= wdata;
            temp_dirty[8] <= 1'b1;

          end

          ADDR_CLEAN_RUN_1: begin

            temp_clean_1 <= wdata;
            temp_dirty[9] <= 1'b1;

          end

          ADDR_CLEAN_RUN_2: begin

            temp_clean_2 <= wdata;
            temp_dirty[10] <= 1'b1;

          end

          default: ;
        endcase

    end
    

    end


    // Multi-byte temps reassembled. Little endian: byte 0 is the low byte.
    logic [23:0] temp_hiccup_full, temp_clean_full;
    always_comb temp_hiccup_full = {temp_hiccup_2, temp_hiccup_1, temp_hiccup_0};
    always_comb temp_clean_full  = {temp_clean_2,  temp_clean_1,  temp_clean_0};

    // Strict multi-byte rule: all three bytes must have been written in this
    // transaction, or none of them commits. A partial write is a firmware bug, and
    // mixing a new low byte with an old high byte is exactly the nonsense value
    // temp flop use exists to prevent.
    logic hiccup_all, hiccup_any, clean_all, clean_any;
    always_comb hiccup_all = &temp_dirty[6:4];
    always_comb hiccup_any = |temp_dirty[6:4];
    always_comb clean_all  = &temp_dirty[10:8];
    always_comb clean_any  = |temp_dirty[10:8];

    // off_ok: the three registers compared against FREE-RUNNING counters are
    //         accepted only in S_OFF, when neither counter is live. A live change
    //         landing below the current count would expire that counter instantly.
    logic off_ok;
    always_comb off_ok = (sup_state == S_OFF);

    // ==================================================================
    // commit and clamp
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Move validated temp values into the live threshold registers, clamping on the
    way IN rather than on the way out. Clamping on write means the register always
    holds a legal value, so a host readback shows what is actually in effect.

    Three gates, all checked here so the policy lives in one place:
      unlock_armed - the threshold bank is locked without a valid key
      off_ok       - hiccup_base, cycles_per_step and clean_run_target are compared
                     against free-running counters, so they are accepted only in
                     S_OFF. trip_run, trip_ss, max_strikes and max_on_limit are
                     compared against bounded accumulators that re-reference every
                     switching cycle, so a mid-run change is safe: lowering one
                     below the current count trips immediately, which is correct.
      hiccup_all / clean_all - strict multi-byte rule, see above.

    write_rejected is set or cleared by every commit, so it always describes the
    most recent write attempt and never goes stale. It is reported in STATUS bit 7;
    the host reads sup_state in the same byte to tell a locked bank from a running
    converter.
    */

    if(!rst_n) begin

        trip_run         <= TRIP_W'(TRIP_RUN_DEFAULT);
        trip_ss          <= TRIP_W'(TRIP_SS_DEFAULT);
        max_strikes      <= STRIKE_W'(MAX_STRIKES_DEFAULT);
        max_on_limit     <= ON_TIME_W'(MAX_ON_COUNTS_DEFAULT);
        hiccup_base      <= HICCUP_BASE_W'(HICCUP_BASE_DEFAULT_CLKS);
        cycles_per_step  <= CYC_STEP_W'(CYCLES_PER_STEP_DEFAULT);
        clean_run_target <= CLEAN_RUN_W'(CLEAN_RUN_CYCLES);
        write_rejected   <= 1'b0;

    end

    else if (integrity_OK) begin

       // A transaction that wrote no threshold at all is not a rejection -
       // leave the flag alone so a control-only write does not clear a
       // genuine rejection the host has not read yet.

       if(|temp_dirty) begin

          write_rejected <= 1'b0;

          if(!unlock_armed) begin

              write_rejected <= 1'b1; //no write access, key not provided

          end

          else begin

            //live thresholds writable at any time
            if(temp_dirty[0]) trip_run     <= clamp_trip_run    (temp_trip_run);
            if(temp_dirty[1]) trip_ss      <= clamp_trip_ss     (temp_trip_ss);
            if(temp_dirty[2]) max_strikes  <= clamp_max_strikes (temp_max_strk);
            if(temp_dirty[3]) max_on_limit <= clamp_max_on      (temp_max_on);

            // ---- S_OFF only ----
            if (temp_dirty[7]) begin
                if (off_ok) cycles_per_step <= clamp_cyc_step(temp_cyc_step);
                else        write_rejected  <= 1'b1;
            end

            if (hiccup_any) begin
                        if (hiccup_all && off_ok) hiccup_base   <= clamp_hiccup(temp_hiccup_full);
                        else                      write_rejected <= 1'b1;
            end

             if (clean_any) begin
                        if (clean_all && off_ok) clean_run_target <= clamp_clean_run(temp_clean_full);
                        else                     write_rejected   <= 1'b1;
             end
        
          end

       end
    end
    end


  


    // ==================================================================
    // control register, keys and arm expiry
    // ==================================================================
    always_ff @(posedge clk or negedge rst_n) begin
    /*
    Purpose:
    ---
    Hold the control bits and manage the two key-protected operations. The enable path
    is asymmetric: enabling takes one write, disabling needs a key first, because a
    spurious enable only removes a veto while a spurious disable stops a working
    supply. latch_clear is a one-clock pulse, not a held value. en_switch_rise is
    applied last so the physical switch wins any same-cycle collision.
    */
    
    if(!rst_n) begin

      arm_timer     <= 1'b0;
      spi_enable    <= 1'b1;
      scratch_r     <= 8'h00;
      log_index     <= 4'h0;
      disable_armed <= 1'b0;
      unlock_armed  <= 1'b0;
      en_pending     <= 1'b0;
      en_pending_val <= 1'b0;

    end

    else begin

      if(disable_armed || unlock_armed) begin

        arm_timer <= arm_timer + 1;

        if(&arm_timer) begin

            disable_armed <= 0;
            unlock_armed  <= 0;

        end
      end

      else begin

          arm_timer <= 1'b0;

      end
  
   

    if(wr_en) begin

      case(addr)

        ADDR_SCRATCH : scratch_r <= wdata;
        ADDR_LOG_INDEX : log_index <= wdata [3:0];

        ADDR_DISABLE_KEY : disable_armed <= (wdata == DISABLE_KEY_ID);
        ADDR_WRITE_KEY : unlock_armed <= (wdata == WRITE_ACCESS_KEY_ID);

        ADDR_CONTROL: begin

          if(wdata[0]) begin
            en_pending     <= 1'b1;
            en_pending_val <= 1'b1;   // enable: no key needed, but still deferred
            disable_armed <= 0;
          end

          else if (disable_armed) begin

            en_pending     <= 1'b1;
            en_pending_val <= 1'b0;   // disable: armed, so honoured at commit
            disable_armed <= 1'b0;

          end
          // A disable attempt with no arm is silently ignored here;

        end

        default: ;
      endcase
    end

    // Apply a pending enable change only on a validated transaction, then clear
    // all pending state. On abort, the pending change is discarded with it.
    if (integrity_OK) begin
        if (en_pending) spi_enable <= en_pending_val;
    end

    if (abort || integrity_OK) begin
        disable_armed  <= 1'b0;
        unlock_armed   <= 1'b0;
        en_pending     <= 1'b0;
        en_pending_val <= 1'b0;
    end

    if(en_switch_rise) spi_enable <= 1'b1;

    end

   end

endmodule

`default_nettype wire

