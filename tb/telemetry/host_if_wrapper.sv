/*

# Filename:         host_if_wrapper.sv

# File Description: Testbench toplevel for the host interface. Contains only
#                   the path the MCU talks to - SPI pin conditioning,
#                   spi_slave and reg_file - wired exactly as in pmic_top.
#                   Every reg_file signal that pmic_top connects to the rest
#                   of the chip is a port here, so cocotb stands in for the
#                   supervisor by driving the status inputs, and observes the
#                   control outputs reg_file would hand to it. The
#                   spi_slave <-> reg_file wires stay internal; cocotb reads
#                   them by hierarchy when it needs to.
#                   Testbench only; never synthesised.

# Global variables: None

*/


`timescale 1ns/1ps
`default_nettype none

module host_if_wrapper 
import pmic_types_pkg::*;
#(
    // SCK_IDLE_TIMEOUT_CLKS: spi_slave's SCK idle timeout, in clk cycles.
    //                        TESTBENCH value - the chip uses ms_to_clks(2),
    //                        about 100,000 cycles. Kept short so timeout
    //                        scenarios run in microseconds; the cocotb
    //                        Makefile can override it with -G.
     parameter int SCK_IDLE_TIMEOUT_CLKS = 100
 )


(   /*
    Each status input carries the name of the pmic_top net that feeds the same
    reg_file port. The *_sync / *_sync_db nets are pmic_top's conditioned
    copies of its input pins - see the pin of the same stem in pmic_top's port
    list (OTP, UVLO, CP, latch_stat, en_from_switch) for what each one means.
    The rest are outputs of supervisor-side modules, documented there.
    */
    
    // ---- clock and reset ----
    input  wire logic clk,          // Clk_Ext, 50 MHz external oscillator
    input  wire logic rst_n,

    //---SPI pins: 4-wire, a separate data line each way
    input  wire logic SCK,
    input  wire logic CS_n,
    input  wire logic MOSI,          // SPI data in, master to supervisor
    output logic      MISO,          // SPI data out, supervisor to master

    /// ---- reg_file status inputs: driven by cocotb in place of the chip ----
    // Named after their pmic_top nets. In the chip these arrive already
    // synchronised and debounced, so cocotb drives them as clean clk-domain
    // levels - no conditioning is modelled here.
    input  wire logic CP_sync,      
    input  wire logic OTP_sync_db,     
    input  wire logic UVLO_sync_db,    
    input  wire logic latch_stat_sync_db,   
    input  wire logic en_from_switch_sync_db, 
    input  wire logic en_switch_rise,
    input  logic [STRIKE_W-1:0] strike_level,
    input  logic [CNT_W-1:0] duty_count,
    input  logic [CNT_W-1:0] prev_period,
    input  logic [TIMESTAMP_W-1:0] timestamp_ms,
    input  logic [TIMESTAMP_W-1:0]   fault_time,
    input  state_t sup_state,
    input  logic [$clog2(WINDOW_RUN+1)-1:0] fault_count_run,
    input  logic [$clog2(WINDOW_SS+1)-1:0]  fault_count_ss,
    input  logic [FAULT_CAUSE_W-1:0] fault_reg,
    input  logic PGOOD,

    // ---- reg_file control outputs: observed by cocotb ----
    // In the chip these feed the supervisor and protection logic; here they
    // let a test confirm that a committed write actually took effect.
    output logic                     spi_enable,
    output logic [TRIP_W-1:0]        trip_run,
    output logic [TRIP_W-1:0]        trip_ss,
    output logic [STRIKE_W-1:0]      max_strikes,
    output logic [ON_TIME_W-1:0]     max_on_limit,
    output logic [HICCUP_BASE_W-1:0] hiccup_base,
    output logic [CYC_STEP_W-1:0]    cycles_per_step,
    output logic [CLEAN_RUN_W-1:0]   clean_run_target,
    output logic fault_reg_read_done,

    // sva_fail_count: running total of SVA failures from every bound
    //                 checker. cocotb cannot read a package variable, so it
    //                 is exposed as a port and the test fails on non-zero.
    output int unsigned sva_fail_count
);
// ---- host access port between spi_slave and reg_file (internal) ----
logic [6:0] spi_addr;
logic       spi_wr_en;
logic [7:0] spi_wdata;
logic [7:0] spi_rdata;
logic       spi_rd_first;
logic       spi_rd_byte_done;   // a read data byte has been clocked out
logic       spi_integrity_ok;
logic       spi_abort;
logic       sdio_out, sdio_oe;   // MISO data, and high only while it is read data

// ---- conditioned SPI lines: synchroniser output, then filter output ----
logic sck_sync,  cs_n_sync,  mosi_sync;

// ============================================================
// SPI bus conditioning
// ============================================================
// Reset values are each line's IDLE level: CS idles high, Mode 0 SCK idles low,
// MOSI idles low. Resetting to the wrong level manufactures an edge on the first
// clock after reset.

input_sync                      u_sck_sync  (.clk(clk), .rst_n(rst_n), .async_in(SCK),  .sync_out(sck_sync));
input_sync #(.RESET_VALUE(1'b1)) u_cs_sync  (.clk(clk), .rst_n(rst_n), .async_in(CS_n), .sync_out(cs_n_sync));
input_sync                      u_mosi_sync (.clk(clk), .rst_n(rst_n), .async_in(MOSI), .sync_out(mosi_sync));

 logic sck_filt,  cs_n_filt,  mosi_filt;


// ============================================================
// SPI line filters
// ============================================================

// input_debounce instanced SYMMETRIC and SHORT, which is a different regime from
// the fault flags it was written for. The symmetry is the critical part: spi_slave
// samples MOSI on an edge derived from SCK, so unequal delay between the two
// shifts the data relative to the clock it is sampled against. All three
// instances must therefore carry IDENTICAL parameters - any future retune of the
// fault-flag instances must not be copied here.
//
// 8 clocks is 160 ns at 50 MHz: far longer than the tens of ns a switch-node edge
// couples in, far shorter than the 500 ns SCK half-period at 1 MHz. Noise lasting
// longer than the window is not a glitch and is not this layer's job - CRC-8 in
// spi_slave catches it and the transaction is discarded.   

input_debounce #(.ASSERT_CLKS(SPI_FILTER_CLKS), .RELEASE_CLKS(SPI_FILTER_CLKS), .RESET_VALUE(1'b0))
    u_sck_filt  (.clk(clk), .rst_n(rst_n), .flag_in(sck_sync),  .flag_out(sck_filt));
input_debounce #(.ASSERT_CLKS(SPI_FILTER_CLKS), .RELEASE_CLKS(SPI_FILTER_CLKS), .RESET_VALUE(1'b1))
    u_cs_filt   (.clk(clk), .rst_n(rst_n), .flag_in(cs_n_sync), .flag_out(cs_n_filt));
input_debounce #(.ASSERT_CLKS(SPI_FILTER_CLKS), .RELEASE_CLKS(SPI_FILTER_CLKS), .RESET_VALUE(1'b0))
    u_mosi_filt (.clk(clk), .rst_n(rst_n), .flag_in(mosi_sync), .flag_out(mosi_filt));
        

// ============================================================
// Host interface
// ============================================================
/*
MISO is driven here and nowhere else. spi_slave's sdio_out carries the read
data and sdio_oe is high exactly while spi_slave is in S_READ, so MISO shows read
data during the read data phase and is held low at every other time - a plain
output, with no tri-state anywhere in the design. Both terms are flops that
change on different SCK edges, so MISO does not glitch. The spi_slave port names
keep the sdio_ prefix of the original 3-wire bus.
*/

assign MISO = sdio_oe & sdio_out;

 spi_slave #(
       .SCK_IDLE_TIMEOUT_CLKS(SCK_IDLE_TIMEOUT_CLKS)
   )  u_spi_slave          (.clk(clk),
                            .rst_n(rst_n),
                            .sck(sck_filt),
                            .cs_n(cs_n_filt),
                            .sdio_in(mosi_filt),
                            .sdio_out(sdio_out),
                            .sdio_oe(sdio_oe),
                            .addr(spi_addr),
                            .wr_en(spi_wr_en),
                            .wdata(spi_wdata),
                            .rdata(spi_rdata),
                            .rd_first(spi_rd_first),
                            .rd_byte_done(spi_rd_byte_done),
                            .integrity_ok(spi_integrity_ok),
                            .txn_abort(spi_abort)
                            );

reg_file u_reg_file     ( .clk(clk),
                          .rst_n(rst_n),
                          // host access port
                          .addr(spi_addr),
                          .wr_en(spi_wr_en),
                          .wdata(spi_wdata),
                          .rdata(spi_rdata),
                          .rd_first(spi_rd_first),
                          .rd_byte_done(spi_rd_byte_done),
                          .integrity_OK(spi_integrity_ok),
                          .txn_abort(spi_abort),
                          // status in - driven by cocotb, standing in for the
                          // supervisor and the conditioned fault flags
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
                          .fault_reg(fault_reg),
                          .timestamp_ms(timestamp_ms),
                          .fault_time(fault_time),
                          .fault_reg_read_done(fault_reg_read_done),
                      
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

// Expose the shared SVA failure tally as a port for the cocotb verdict.
assign sva_fail_count = sva_pkg::sva_failures;

endmodule

`default_nettype wire

