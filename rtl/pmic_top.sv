/*

# Filename:         pmic_top.sv

# File Description: Top level of the CPLD supervisor. Instantiates the reset
#                    synchroniser and one input synchroniser per asynchronous
#                    pin, then wires the supervisor FSM to the soft-start
#                    ramp, per-cycle PWM mask, rolling fault window, hiccup
#                    cool-down, strike counter and power-good generator.
#
#                    All clock domain crossing lives here: every signal from
#                    the analog side is comparator output with no relation to
#                    clk, and no submodule sees a raw pin. Each asynchronous
#                    input is synchronised once and the result distributed.
#
#                    OTP, UVLO, latch_stat and the enable switch pass
#                    through input_debounce between the synchroniser and
#                    the supervisor. CP_trig does not: fault_arbiter's
#                    rolling window already provides the duration filter.
#                    PGOOD_comp does not either: pgood_gen's deassert is
#                    immediate by design so the rail hands back before the
#                    output collapses.

# Global variables: None

*/

`default_nettype none

module pmic_top (
    // ---- clock and reset ----
    input  wire logic clk,          // Clk_Ext, 50 MHz external oscillator
    input  wire logic rst_n_pin,    // asynchronous external reset, active low

    //---SPI pins
    input  wire logic SCK,
    input  wire logic CS_n,
    inout  wire logic SDIO,          //3 wire SPI

    // ---- asynchronous inputs from the analog side ----
    input  wire logic Osc_in,       // Master_PWM from the analog modulator
    input  wire logic CP_trig,      // valley-current comparator
    input  wire logic OTP_trig,     // over-temperature comparator
    input  wire logic UVLO_trig,    // input undervoltage lockout comparator
    input  wire logic latch_stat,   // SCR protection latch, read back
    input  wire logic PGOOD_comp,   // output rail comparator
    input  wire logic en_from_switch, //Hardware switch input, driven by user physically

    // ---- outputs ----
    output logic PWM_out,      // masked PWM to the LM5106 IN pin
    output logic En,           // LM5106 enable driven by the supervisor FSM
    output logic PGOOD,        // supply changeover and telemetry
    output logic latch_out,    // CPLD-driven trip into the shared latch
    output logic switch_supply // NPN drive for the housekeeping rail changeover
);

    import pmic_types_pkg::*;



    // ---- reset synchronization----
    logic rst_n;
    reset_sync rst_sync (.clk(clk), .rst_n_enter(rst_n_pin), .rst_n_exit(rst_n));

    // --- switch supply from HV LDO to buck for housekeeping

   

    // ---- synchronised copies of the asynchronous inputs ----
    logic  en_from_switch_sync, Osc_sync, CP_sync, OTP_sync, UVLO_sync, latch_stat_sync, PGOOD_comp_sync;


    // ============================================================
    // Input synchronisers
    // ============================================================

    input_sync u_osc_sync (.clk(clk), .rst_n(rst_n), .async_in(Osc_in), .sync_out(Osc_sync));
    input_sync #(.RESET_VALUE(1'b1)) u_cp_sync (.clk(clk), .rst_n(rst_n), .async_in(CP_trig), .sync_out(CP_sync));
    input_sync #(.RESET_VALUE(1'b1)) u_otp_sync (.clk(clk), .rst_n(rst_n), .async_in(OTP_trig), .sync_out(OTP_sync));
    input_sync #(.RESET_VALUE(1'b1)) u_uvlo_sync (.clk(clk), .rst_n(rst_n), .async_in(UVLO_trig), .sync_out(UVLO_sync));
    input_sync #(.RESET_VALUE(1'b1)) u_latch_stat_sync (.clk(clk), .rst_n(rst_n), .async_in(latch_stat), .sync_out(latch_stat_sync));
    input_sync u_pgood_comp_sync(.clk(clk), .rst_n(rst_n), .async_in(PGOOD_comp), .sync_out(PGOOD_comp_sync));
    input_sync u_en_from_switch_sync  (.clk(clk), .rst_n(rst_n), .async_in(en_from_switch), .sync_out(en_from_switch_sync));
    

    // ---- SPI bus, synchronised then filtered ----
    // SPI_FILTER_CLKS: identical on all three lines. Unequal delay between SCK and
    //                  SDIO shifts the data relative to the clock it is sampled
    //                  against, which is worse than no filtering at all.
    localparam int SPI_FILTER_CLKS = 8;     // 160 ns at 50 MHz

    logic sck_sync,  cs_n_sync,  sdio_sync;
    logic sck_filt,  cs_n_filt,  sdio_filt;

    // ============================================================
    // SPI bus conditioning
    // ============================================================
    // Reset values are each line's IDLE level: CS idles high, Mode 0 SCK idles low,
    // SDIO idles released and reads low through the pull-down. Resetting to the wrong
    // level manufactures an edge on the first clock after reset.

    

    input_sync                      u_sck_sync  (.clk(clk), .rst_n(rst_n), .async_in(SCK),  .sync_out(sck_sync));
    input_sync #(.RESET_VALUE(1'b1)) u_cs_sync  (.clk(clk), .rst_n(rst_n), .async_in(CS_n), .sync_out(cs_n_sync));
    input_sync                      u_sdio_sync (.clk(clk), .rst_n(rst_n), .async_in(SDIO), .sync_out(sdio_sync));

    spi_filter #(.FILTER_CLKS(SPI_FILTER_CLKS), .RESET_VALUE(1'b0))
        u_sck_filt  (.clk(clk), .rst_n(rst_n), .raw_in(sck_sync),  .filt_out(sck_filt));
    spi_filter #(.FILTER_CLKS(SPI_FILTER_CLKS), .RESET_VALUE(1'b1))
        u_cs_filt   (.clk(clk), .rst_n(rst_n), .raw_in(cs_n_sync), .filt_out(cs_n_filt));
    spi_filter #(.FILTER_CLKS(SPI_FILTER_CLKS), .RESET_VALUE(1'b0))
        u_sdio_filt (.clk(clk), .rst_n(rst_n), .raw_in(sdio_sync), .filt_out(sdio_filt));

    //-- debounced inputs--//
     logic en_from_switch_sync_db;
     logic OTP_sync_db;
     logic UVLO_sync_db;
     logic latch_stat_sync_db;

    // ============================================================
    // Input debouncers
    // ============================================================

    input_debounce #(.ASSERT_CLKS (ms_to_clks(20)),
                     .RELEASE_CLKS(ms_to_clks(20)),
                     .RESET_VALUE (1'b0))
    u_en_from_switch_db (.clk(clk), .rst_n(rst_n),
                             .flag_in(en_from_switch_sync),
                             .flag_out(en_from_switch_sync_db));
    input_debounce u_OTP_sync_db (.clk(clk), .rst_n(rst_n), .flag_in(OTP_sync), .flag_out(OTP_sync_db));
    input_debounce u_UVLO_sync_db (.clk(clk), .rst_n(rst_n), .flag_in (UVLO_sync), .flag_out(UVLO_sync_db));
    input_debounce u_latch_stat_sync_db (.clk(clk), .rst_n(rst_n), .flag_in(latch_stat_sync), .flag_out(latch_stat_sync_db));


    // ---- inter-module signals ----

    logic ss_active, run_active, hiccup_active, hiccup_done, SS_done;
    logic window_trip, window_trip_SS;
    logic [STRIKE_W-1:0]strike_level;
    logic [ON_TIME_W-1:0] max_on_counts;
    logic [CNT_W-1:0] duty_count;
    logic [CNT_W-1:0] prev_period;

    
    // Driven here, consumed by reg_file. 
    state_t sup_state;
    logic [$clog2(WINDOW_RUN+1)-1:0] fault_count_run;
    logic [$clog2(WINDOW_SS+1)-1:0]  fault_count_ss;
    logic en_switch_rise;  //en_from_switch_sync_db edge detction pulse
    

   

    // ---- host access port between spi_slave and reg_file ----
    logic [6:0] spi_addr;
    logic       spi_wr_en;
    logic [7:0] spi_wdata;
    logic [7:0] spi_rdata;
    logic       spi_rd_first;
    logic       spi_integrity_ok;
    logic       spi_abort;
    logic       sdio_out, sdio_oe;


    // ---- reg_file control outputs ----
    logic                     spi_enable;
    logic [TRIP_W-1:0]        trip_run;
    logic [TRIP_W-1:0]        trip_ss;
    logic [STRIKE_W-1:0]      max_strikes;
    logic [ON_TIME_W-1:0]     max_on_limit;
    logic [HICCUP_BASE_W-1:0] hiccup_base;
    logic [CYC_STEP_W-1:0]    cycles_per_step;
    logic [CLEAN_RUN_W-1:0]   clean_run_target;

    logic en_from_switch_sync_db_d; //delayed en_from_switch_sync_db

    always_ff @(posedge clk or negedge rst_n) begin
        /*
        Purpose: Stores delayed copy of en_from_switch_sync_db for edge detection
        
        */
        if(!rst_n)begin
            en_from_switch_sync_db_d <= 0;
        end

        else
            en_from_switch_sync_db_d <= en_from_switch_sync_db;

    end

    always_comb begin

        /*
        Purpose: Edge detection on the physical enable switch signal synced and debounced
        */

        en_switch_rise = ~en_from_switch_sync_db_d & en_from_switch_sync_db;

    end
    // ============================================================
    // Supervisor FSM
    // ============================================================

    supervisor u_supervisor ( .clk(clk),
                            .SS_done(SS_done),
                            .rst_n(rst_n),
                            .en_SW(en_from_switch_sync_db),
                            .spi_enable(spi_enable),
                            .latch_state(latch_stat_sync_db),
                            .OTP(OTP_sync_db),
                            .window_trip_SS(window_trip_SS),
                            .window_trip(window_trip),
                            .latch_assert(latch_out),
                            .UVLO(UVLO_sync_db),
                            .hiccup_done(hiccup_done),
                            .en(En),
                            .ss_active(ss_active),
                            .run_active(run_active),
                            .hiccup_active(hiccup_active),
                            .state_out(sup_state)
                            );


    // ============================================================
    // Protection
    // ============================================================
    // 
    fault_arbiter u_fault_arbiter ( .clk(clk),
                                    .rst_n(rst_n),
                                    .trip_run(trip_run),
                                    .trip_ss(trip_ss),
                                    .fault_count_run_out(fault_count_run),
                                    .fault_count_ss_out(fault_count_ss),
                                    .pwm_sync(Osc_sync),
                                    .cp_sync(CP_sync),
                                    .ss_active(ss_active),
                                    .run_active(run_active),
                                    .window_trip(window_trip),
                                    .window_trip_SS(window_trip_SS)
                                    );
    hiccup_timer u_hiccup_timer ( .clk(clk),
                                    .rst_n(rst_n),
                                    .base_clks(hiccup_base),
                                    .hiccup_active(hiccup_active),
                                    .strike_level(strike_level),
                                    .hiccup_done(hiccup_done)
                                    );
    
    strike_counter u_strike_counter ( .clk(clk),
                                    .rst_n(rst_n),
                                    .max_strikes(max_strikes),
                                    .clean_run_target(clean_run_target),
                                    .pwm_sync(Osc_sync),
                                    .hiccup_active(hiccup_active),
                                    .run_active(run_active),
                                    .window_trip(window_trip),
                                    .strike_level(strike_level),
                                    .latch_assert(latch_out)
                                    );
    soft_start u_soft_start ( .clk(clk),
                                    .rst_n(rst_n),
                                    .pwm_sync(Osc_sync),
                                    .ss_active(ss_active),
                                    .run_active(run_active),
                                    .max_on_counts(max_on_counts),
                                    .max_on_limit(max_on_limit),
                                    .cycles_per_step(cycles_per_step),
                                    .SS_done(SS_done)
                                    );

    pwm_mask u_pwm_mask ( .clk(clk),
                            .rst_n(rst_n),
                            .pwm_sync(Osc_sync),
                            .max_on_counts(max_on_counts),
                            .pwm_out(PWM_out)
                            );

    // ============================================================
    // Host interface
    // ============================================================
    /*
    The SDIO tri-state lives HERE and nowhere else, so Verilator, ModelSim and the
    hardware all see the same behaviour. spi_slave exposes sdio_out and sdio_oe and
    never touches a bidirectional net itself.
    */
    assign SDIO = sdio_oe ? sdio_out : 1'bz;

    spi_slave u_spi_slave ( .clk(clk),
                            .rst_n(rst_n),
                            .sck(sck_filt),
                            .cs_n(cs_n_filt),
                            .sdio_in(sdio_filt),
                            .sdio_out(sdio_out),
                            .sdio_oe(sdio_oe),
                            .addr(spi_addr),
                            .wr_en(spi_wr_en),
                            .wdata(spi_wdata),
                            .rdata(spi_rdata),
                            .rd_first(spi_rd_first),
                            .integrity_ok(spi_integrity_ok),
                            .abort(spi_abort)
                            );

    reg_file u_reg_file ( .clk(clk),
                          .rst_n(rst_n),

                          // host access port
                          .addr(spi_addr),
                          .wr_en(spi_wr_en),
                          .wdata(spi_wdata),
                          .rdata(spi_rdata),
                          .rd_first(spi_rd_first),
                          .integrity_OK(spi_integrity_ok),
                          .abort(spi_abort),

                          // status in - debounced copies, so telemetry matches what
                          // the supervisor is actually acting on
                          .sup_state(sup_state),
                          .pgood(PGOOD),
                          .latch_state(latch_stat_sync_db),
                          .en_switch(en_from_switch_sync_db),
                          .en_switch_rise(en_switch_rise),
                          .cp_state(CP_sync),
                          .otp_state(OTP_sync_db),
                          .uvlo_state(UVLO_sync_db),
                          .strike_level(strike_level),
                          .duty_count(duty_count),          
                          .prev_period(prev_period),         
                          .fault_count_run(fault_count_run),
                          .fault_count_ss(fault_count_ss),

                          // @TODO not built - CAPABILITY_VAL reports them absent
                          .peak_fault_run('0),
                          .cycle_count('0),
                          .bus_err_count('0),
                          .log_entry('0),
                          .log_index(),

                          // control out
                          .spi_enable(spi_enable),
                          .trip_run(trip_run),
                          .trip_ss(trip_ss),
                          .max_strikes(max_strikes),
                          .max_on_limit(max_on_limit),
                          .hiccup_base(hiccup_base),
                          .cycles_per_step(cycles_per_step),
                          .clean_run_target(clean_run_target)
                          );

    // ============================================================
    // Status
    // ============================================================

    pgood_gen u_pgood_gen ( .clk(clk),
                            .rst_n(rst_n),
                            .pwm_sync(Osc_sync),
                            .pgood_comp(PGOOD_comp_sync),
                            .run_active(run_active),
                            .PGOOD(PGOOD)
                            );

        /*
    Telemetry only. pwm_stats drives no control path and takes no part in any
    protection timing, so it runs unconditionally from the synchronised PWM rather
    than being gated on any supervisor state - duty and period are as interesting
    during a fault as during normal running.
    */
    pwm_stats u_pwm_stats ( .clk(clk),
                            .rst_n(rst_n),
                            .pwm_sync(Osc_sync),
                            .duty_count(duty_count),
                            .prev_period(prev_period)
                            );

     /*
    switch_supply carries the same value as PGOOD but is a separate pin
    because the two have different electrical jobs. PGOOD is telemetry,
    driven into a high-impedance input. switch_supply sources base current
    into the NPN that pulls the P-FET gate down, so it carries real
    current and is the pin whose drive strength and series resistor
    matter. Keeping them separate also keeps the changeover's switching
    noise off the telemetry net.

    The deassert is immediate, inherited from pgood_gen. No delay is added
    here because the supervisor cannot observe how far the rail has
    actually sagged - PGOOD_comp is a window comparator and reports only
    in or out, so a droop and a collapse are indistinguishable. Handing
    back at the first sign is the only assumption that is safe in both
    cases, and it hands back while the buck output is still above the HV
    LDO setpoint, so the node is carried by the body diode until the
    Schottky picks up rather than waiting on the LDO loop.
    */
    assign switch_supply = PGOOD;


    /*
    PWM_out is not gated by En in logic. En drives the LM5106 enable pin,
    which holds both gate outputs low regardless of what the PWM input is
    doing, so a second gate here would be a second shutdown path to keep
    consistent. latch_out is driven straight from strike_counter's
    latch_assert and is also read back by the supervisor.
    */


endmodule

`default_nettype wire

