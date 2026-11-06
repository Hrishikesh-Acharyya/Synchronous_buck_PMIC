/*

# Filename:         reg_file_sva.sv

# File Description: Concurrent assertion checker for reg_file. Attached with
#                   bind so the RTL carries no assertion constructs and the
#                   sv2v / Yosys ASIC path never sees them.
#
#                   SCOPE. This file owns the rules that hold cycle by cycle:
#                   reset values, the commit discipline (no live register moves
#                   except on integrity_OK, no pending state survives a
#                   transaction), the threshold gates and their all-or-nothing
#                   rule, the safe range of every threshold, the keys, the
#                   ways spi_enable may move, the bus-silence watchdog, the
#                   fixed and unmapped read values, the timestamp snapshot,
#                   the fault-record clear pulse and the bus-error counter.
#                   The value claims go to the cocotb scoreboard instead: that
#                   a committed threshold equals the written value clamped,
#                   that every mapped address reads its documented source
#                   (STATUS packing included), and that a timestamp burst is
#                   coherent. Those are M claims - the expected value depends
#                   on the writes the testbench chose.
#
#                   INTERNALS. Read through dut_ ports connected in
#                   bind_sva.sv: the pending state (temp_dirty, en_pending,
#                   en_pending_val, scratch_pending), the keys and arm timer,
#                   the watchdog mark and flag, write_rejected, scratch_r,
#                   bus_err_count and timestamp_snap. All are declared and
#                   described in reg_file's "Internal state" section, so they
#                   are contract rather than implementation detail.
#
#                   INDEPENDENCE. threshold_reject is NOT read from the DUT.
#                   The S_OFF gate, the all-three-bytes rule and the key gate
#                   are each checked directly from sup_state, temp_dirty and
#                   unlock_armed; only the cross-register all-or-nothing claim
#                   needs a rejection decision, and chk_reject rebuilds it from
#                   the contract's three conditions.
#
#                   COPIED CONSTANTS. The register addresses, CAPABILITY_VAL
#                   and WD_TIMEOUT_MS are localparams inside reg_file, not
#                   parameters, so they are copied here from its header. A
#                   mismatch makes the read or watchdog properties fire, so it
#                   cannot hide.

# Global variables: None

*/

`default_nettype none

module reg_file_sva
    import pmic_types_pkg::*;
#(
    // PMIC_ID / VERSION_ID: passed through from the bound instance - the fixed
    //                       identity bytes the read port must return
    parameter logic [7:0] PMIC_ID             = 8'hB5,
    parameter logic [7:0] VERSION_ID          = 8'h01,
    // DISABLE_KEY_ID / WRITE_ACCESS_KEY_ID: the magic bytes that arm the two keys
    parameter logic [7:0] DISABLE_KEY_ID      = 8'hD1,
    parameter logic [7:0] WRITE_ACCESS_KEY_ID = 8'hA7,
    // ARM_TIMEOUT_W: width of reg_file's arm expiry counter
    parameter int         ARM_TIMEOUT_W       = 16
)(
    input  wire logic                     clk,
    input  wire logic                     rst_n,

    // ---- host access port ----
    input  wire logic [6:0]               addr,
    input  wire logic                     wr_en,
    input  wire logic [7:0]               wdata,
    input  wire logic [7:0]               rdata,
    input  wire logic                     rd_first,
    input  wire logic                     rd_byte_done,
    input  wire logic                     integrity_OK,
    input  wire logic                     txn_abort,

    // ---- status in ----
    input  state_t                        sup_state,
    input  wire logic                     en_switch_rise,
    input  wire logic [TIMESTAMP_W-1:0]   timestamp_ms,

    // ---- control out ----
    input  wire logic                     spi_enable,
    input  wire logic [TRIP_W-1:0]        trip_run,
    input  wire logic [TRIP_W-1:0]        trip_ss,
    input  wire logic [STRIKE_W-1:0]      max_strikes,
    input  wire logic [ON_TIME_W-1:0]     max_on_limit,
    input  wire logic [HICCUP_BASE_W-1:0] hiccup_base,
    input  wire logic [CYC_STEP_W-1:0]    cycles_per_step,
    input  wire logic [CLEAN_RUN_W-1:0]   clean_run_target,
    input  wire logic                     fault_reg_read_done,

    // ---- DUT internals, connected explicitly in bind_sva.sv ----
    input  wire logic [7:0]               dut_scratch_r,
    input  wire logic [10:0]              dut_temp_dirty,
    input  wire logic                     dut_en_pending,
    input  wire logic                     dut_en_pending_val,
    input  wire logic                     dut_scratch_pending,
    input  wire logic                     dut_disable_armed,
    input  wire logic                     dut_unlock_armed,
    input  wire logic [ARM_TIMEOUT_W-1:0] dut_arm_timer,
    input  wire logic [TIMESTAMP_W-1:0]   dut_wd_mark,
    input  wire logic                     dut_wd_restored,
    input  wire logic                     dut_write_rejected,
    input  wire logic [15:0]              dut_bus_err_count,
    input  wire logic [TIMESTAMP_W-1:0]   dut_timestamp_snap
);

// ADDR_*: reg_file's register map, copied from its header
localparam logic [6:0] ADDR_PMIC_ID     = 7'h00;
localparam logic [6:0] ADDR_VERSION     = 7'h01;
localparam logic [6:0] ADDR_CAPABILITY  = 7'h02;
localparam logic [6:0] ADDR_FTIME_2     = 7'h20;
localparam logic [6:0] ADDR_DISABLE_KEY = 7'h40;
localparam logic [6:0] ADDR_CONTROL     = 7'h41;
localparam logic [6:0] ADDR_WRITE_KEY   = 7'h4F;

// CAPABILITY_VAL: the build-configuration byte at 0x02, copied from reg_file
localparam logic [7:0] CAPABILITY_VAL = 8'b0011_1101;

// WD_TIMEOUT_MS: host silence tolerated while the veto is held, copied from reg_file
localparam int WD_TIMEOUT_MS = 5000;

// chk_off_ok: the converter is in S_OFF, the only state in which hiccup_base,
//             cycles_per_step and clean_run_target may change
logic chk_off_ok;

// chk_hiccup_any / chk_hiccup_all: some / all three hiccup_base bytes written
//                                  in this transaction
logic chk_hiccup_any, chk_hiccup_all;

// chk_clean_any / chk_clean_all: the same for clean_run_target
logic chk_clean_any, chk_clean_all;

// chk_reject: the contract's rejection rule - no key, an S_OFF-only register
//             outside S_OFF, or a partial multi-byte write. Rebuilt here,
//             never read from the DUT.
logic chk_reject;

// chk_wd_expired: the veto is held and the host has not completed a valid
//                 write for WD_TIMEOUT_MS. Unsigned subtraction, so a
//                 timestamp_ms wrap still gives the right interval.
logic chk_wd_expired;

// chk_addr_mapped: addr names a register in reg_file's map; everything else
//                  must read 0x00
logic chk_addr_mapped;

assign chk_off_ok     = (sup_state == S_OFF);
assign chk_hiccup_any = |dut_temp_dirty[6:4];
assign chk_hiccup_all = &dut_temp_dirty[6:4];
assign chk_clean_any  = |dut_temp_dirty[10:8];
assign chk_clean_all  = &dut_temp_dirty[10:8];
assign chk_reject     = !dut_unlock_armed
                      || (dut_temp_dirty[7] && !chk_off_ok)
                      || (chk_hiccup_any && !(chk_hiccup_all && chk_off_ok))
                      || (chk_clean_any  && !(chk_clean_all  && chk_off_ok));
assign chk_wd_expired = !spi_enable
                      && ((timestamp_ms - dut_wd_mark) >= TIMESTAMP_W'(WD_TIMEOUT_MS));

always_comb begin
  /*
  Purpose:
  ---
  Decode whether addr names a mapped register, from the map in reg_file's
  header. 0x17 and every gap between banks are deliberately absent.
  */
  case (addr)
    7'h00, 7'h01, 7'h02, 7'h03,
    7'h10, 7'h11, 7'h12, 7'h13, 7'h14, 7'h15, 7'h16,
    7'h18, 7'h19, 7'h1A, 7'h1B, 7'h1C, 7'h1D, 7'h1E, 7'h1F, 7'h20,
    7'h40, 7'h41, 7'h4F,
    7'h50, 7'h51, 7'h52, 7'h53, 7'h54, 7'h55, 7'h56, 7'h57,
    7'h58, 7'h59, 7'h5A          : chk_addr_mapped = 1'b1;
    default                      : chk_addr_mapped = 1'b0;
  endcase
end


/*
Purpose: PAC(Property, Assertion, Cover) Group 1 (contract A1):
         Every register at its reset value while rst_n is low: thresholds at
         their package defaults, spi_enable high, SCRATCH zero, both keys
         disarmed, no rejection, no bus errors, no watchdog flag, no pending
         state. No disable iff - reset is the condition under test.
*/

property p_reset_values;
  @(posedge clk)
    (!rst_n) |-> ((trip_run         == TRIP_W'(TRIP_RUN_DEFAULT))
               && (trip_ss          == TRIP_W'(TRIP_SS_DEFAULT))
               && (max_strikes      == STRIKE_W'(MAX_STRIKES_DEFAULT))
               && (max_on_limit     == ON_TIME_W'(MAX_ON_COUNTS_DEFAULT))
               && (hiccup_base      == HICCUP_BASE_W'(HICCUP_BASE_DEFAULT_CLKS))
               && (cycles_per_step  == CYC_STEP_W'(CYCLES_PER_STEP_DEFAULT))
               && (clean_run_target == CLEAN_RUN_W'(CLEAN_RUN_CYCLES))
               && spi_enable
               && (dut_scratch_r == 8'h00)
               && !dut_disable_armed && !dut_unlock_armed
               && !dut_write_rejected && !dut_wd_restored
               && (dut_bus_err_count == 16'h0000)
               && (dut_temp_dirty == '0) && !dut_en_pending && !dut_scratch_pending);
endproperty

a_reset_values: assert property (p_reset_values)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_reset_values: trip_run=%0d trip_ss=%0d strikes=%0d max_on=%0d en=%0b scratch=%0h armed=%0b/%0b rej=%0b err=%0d dirty=%0h",
      trip_run, trip_ss, max_strikes, max_on_limit, spi_enable, dut_scratch_r,
      dut_disable_armed, dut_unlock_armed, dut_write_rejected, dut_bus_err_count, dut_temp_dirty));
  end

c_in_reset: cover property (@(posedge clk) (!rst_n));

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 2 (contract B1, B3):
         The commit discipline.
           - No host-writable live register (the seven thresholds, SCRATCH)
             changes except on the clock after integrity_OK.
           - No pending state survives a transaction boundary: after
             integrity_OK or txn_abort there are no dirty temps, no pending
             CONTROL or SCRATCH write, and both keys are disarmed.
         Considered and subsumed: contract B4 ("txn_abort changes no live
         register") follows from the first property, since integrity_OK and
         txn_abort never share a clock.
*/

property p_live_regs_move_only_on_commit;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !integrity_OK)
        |=> $stable({trip_run, trip_ss, max_strikes, max_on_limit,
                     hiccup_base, cycles_per_step, clean_run_target, dut_scratch_r});
endproperty

a_live_regs_move_only_on_commit: assert property (p_live_regs_move_only_on_commit)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_live_regs_move_only_on_commit: a live register changed with no integrity_OK (trip_run %0d->%0d, scratch %0h->%0h)",
      $past(trip_run), trip_run, $past(dut_scratch_r), dut_scratch_r));
  end

property p_no_state_survives_transaction;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && (integrity_OK || txn_abort))
        |=> ((dut_temp_dirty == '0) && !dut_en_pending && !dut_en_pending_val
             && !dut_scratch_pending && !dut_disable_armed && !dut_unlock_armed);
endproperty

a_no_state_survives_transaction: assert property (p_no_state_survives_transaction)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_no_state_survives_transaction: after the end pulse dirty=%0h en_pending=%0b scratch_pending=%0b armed=%0b/%0b",
      dut_temp_dirty, dut_en_pending, dut_scratch_pending, dut_disable_armed, dut_unlock_armed));
  end

c_commit:                cover property (@(posedge clk) disable iff (!rst_n) integrity_OK);
c_abort_with_pending:    cover property (@(posedge clk) disable iff (!rst_n)
                             txn_abort && ((|dut_temp_dirty) || dut_en_pending || dut_scratch_pending
                                           || dut_disable_armed || dut_unlock_armed));
c_scratch_committed:     cover property (@(posedge clk) disable iff (!rst_n)
                             integrity_OK && dut_scratch_pending);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 3 (contract C1):
         Every live threshold is always inside the range proved safe at design
         time. The safety claim of the module: no sequence of host writes can
         place the hardware outside these bounds - max_on_limit above its
         default would starve the LM5106 bootstrap and destroy the FET.
         clean_run_target's upper bound is its full width, so only its lower
         bound is checked.
*/

// max_strikes' ceiling is checked separately, in g_strike_ceiling: while
// STRIKE_W holds exactly MAX_STRIKES_DEFAULT, the width alone enforces it and a
// "<=" here would be a constant comparison (CMPCONST).
property p_thresholds_in_safe_range;

  @(posedge clk) disable iff (!rst_n)
    (trip_run         >= TRIP_W'(1))                           && (trip_run        <= TRIP_W'(WINDOW_RUN))
 && (trip_ss          >= TRIP_W'(1))                           && (trip_ss         <= TRIP_W'(WINDOW_SS))
 && (max_strikes      >= STRIKE_W'(1))
 && (max_on_limit     >= ON_TIME_W'(MIN_ON_COUNTS))            && (max_on_limit    <= ON_TIME_W'(MAX_ON_COUNTS_DEFAULT))
 && (cycles_per_step  >= CYC_STEP_W'(1))                       && (cycles_per_step <= CYC_STEP_W'(CYCLES_PER_STEP_MAX))
 && (hiccup_base      >= HICCUP_BASE_W'(HICCUP_BASE_MIN_CLKS)) && (hiccup_base     <= HICCUP_BASE_W'(HICCUP_BASE_MAX_CLKS))
 && (clean_run_target >= CLEAN_RUN_W'(CLEAN_RUN_MIN_CYCLES));

endproperty

a_thresholds_in_safe_range: assert property (p_thresholds_in_safe_range)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_thresholds_in_safe_range: trip_run=%0d trip_ss=%0d strikes=%0d max_on=%0d cyc=%0d hiccup=%0d clean=%0d",
      trip_run, trip_ss, max_strikes, max_on_limit, cycles_per_step, hiccup_base, clean_run_target));
  end

// g_strike_ceiling: max_strikes' upper bound, elaborated only while the
// register is wide enough to exceed it. With MAX_STRIKES_DEFAULT = 3 and
// STRIKE_W = 2 the width itself is the bound and nothing is generated.
generate if (((2 ** STRIKE_W) - 1) > MAX_STRIKES_DEFAULT) begin : g_strike_ceiling

  a_max_strikes_ceiling: assert property (
    @(posedge clk) disable iff (!rst_n)
      max_strikes <= STRIKE_W'(MAX_STRIKES_DEFAULT))
    else begin
      sva_pkg::note_failure($sformatf(
        "a_max_strikes_ceiling: max_strikes=%0d above the default %0d",
        max_strikes, MAX_STRIKES_DEFAULT));
    end

end endgenerate

c_max_on_at_ceiling: cover property (@(posedge clk) disable iff (!rst_n)
                         integrity_OK && dut_temp_dirty[3] && !chk_reject);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 4 (contract C2-C4, C6, C7):
         The threshold commit gates, each checked on its own.
           - No key, no change: a commit without unlock_armed moves nothing.
           - S_OFF only: hiccup_base, cycles_per_step and clean_run_target
             never change at a commit outside S_OFF.
           - All three bytes: hiccup_base and clean_run_target never change
             unless all three of their bytes were written.
           - Only what was written: a threshold whose temp was not dirty is
             untouched by a commit.
           - All or nothing: a commit the contract rejects moves no threshold
             at all, even ones that would have been legal on their own.
           - write_rejected changes only at a commit that wrote a threshold,
             and then equals the contract's rejection decision.
         That every accepted threshold DID take its clamped value is an M
         claim for the scoreboard.
*/

property p_no_key_no_change;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && integrity_OK && !dut_unlock_armed)
        |=> $stable({trip_run, trip_ss, max_strikes, max_on_limit,
                     hiccup_base, cycles_per_step, clean_run_target});
endproperty

a_no_key_no_change: assert property (p_no_key_no_change)
  else begin
    sva_pkg::note_failure("a_no_key_no_change: a threshold changed at a commit without the write key");
  end

property p_off_only_registers;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && integrity_OK && !chk_off_ok)
        |=> $stable({hiccup_base, cycles_per_step, clean_run_target});
endproperty

a_off_only_registers: assert property (p_off_only_registers)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_off_only_registers: an S_OFF-only threshold changed in state %0d", $past(sup_state)));
  end

property p_multibyte_whole_or_nothing;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && integrity_OK)
        |=> (($past(chk_hiccup_all) || $stable(hiccup_base))
          && ($past(chk_clean_all)  || $stable(clean_run_target)));
endproperty

a_multibyte_whole_or_nothing: assert property (p_multibyte_whole_or_nothing)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_multibyte_whole_or_nothing: a multi-byte threshold changed from a partial write (dirty=%0h)",
      $past(dut_temp_dirty)));
  end

property p_only_written_thresholds_change;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && integrity_OK)
        |=> (($past(dut_temp_dirty[0]) || $stable(trip_run))
          && ($past(dut_temp_dirty[1]) || $stable(trip_ss))
          && ($past(dut_temp_dirty[2]) || $stable(max_strikes))
          && ($past(dut_temp_dirty[3]) || $stable(max_on_limit))
          && ($past(dut_temp_dirty[7]) || $stable(cycles_per_step))
          && ($past(chk_hiccup_any)    || $stable(hiccup_base))
          && ($past(chk_clean_any)     || $stable(clean_run_target)));
endproperty

a_only_written_thresholds_change: assert property (p_only_written_thresholds_change)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_only_written_thresholds_change: an unwritten threshold changed at a commit (dirty=%0h)",
      $past(dut_temp_dirty)));
  end

property p_rejected_commit_changes_nothing;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && integrity_OK && (|dut_temp_dirty) && chk_reject)
        |=> $stable({trip_run, trip_ss, max_strikes, max_on_limit,
                     hiccup_base, cycles_per_step, clean_run_target});
endproperty

a_rejected_commit_changes_nothing: assert property (p_rejected_commit_changes_nothing)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_rejected_commit_changes_nothing: a rejected commit changed a threshold (dirty=%0h key=%0b state=%0d)",
      $past(dut_temp_dirty), $past(dut_unlock_armed), $past(sup_state)));
  end

property p_write_rejected_only_at_threshold_commit;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !(integrity_OK && (|dut_temp_dirty)))
        |=> $stable(dut_write_rejected);
endproperty

a_write_rejected_only_at_threshold_commit: assert property (p_write_rejected_only_at_threshold_commit)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_write_rejected_only_at_threshold_commit: write_rejected went %0b -> %0b outside a threshold commit",
      $past(dut_write_rejected), dut_write_rejected));
  end

property p_write_rejected_matches_decision;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && integrity_OK && (|dut_temp_dirty))
        |=> (dut_write_rejected == $past(chk_reject));
endproperty

a_write_rejected_matches_decision: assert property (p_write_rejected_matches_decision)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_write_rejected_matches_decision: write_rejected=%0b, contract says %0b (dirty=%0h key=%0b state=%0d)",
      dut_write_rejected, $past(chk_reject), $past(dut_temp_dirty), $past(dut_unlock_armed), $past(sup_state)));
  end

c_threshold_accepted:   cover property (@(posedge clk) disable iff (!rst_n)
                            integrity_OK && (|dut_temp_dirty) && !chk_reject);
c_rejected_no_key:      cover property (@(posedge clk) disable iff (!rst_n)
                            integrity_OK && (|dut_temp_dirty) && !dut_unlock_armed);
c_rejected_not_off:     cover property (@(posedge clk) disable iff (!rst_n)
                            integrity_OK && dut_unlock_armed && !chk_off_ok
                            && (dut_temp_dirty[7] || chk_hiccup_any || chk_clean_any));
c_rejected_partial:     cover property (@(posedge clk) disable iff (!rst_n)
                            integrity_OK && dut_unlock_armed && chk_off_ok
                            && ((chk_hiccup_any && !chk_hiccup_all) || (chk_clean_any && !chk_clean_all)));
c_mixed_set_rejected:   cover property (@(posedge clk) disable iff (!rst_n)
                            integrity_OK && chk_reject && dut_unlock_armed && (|dut_temp_dirty[3:0]));
c_control_only_commit:  cover property (@(posedge clk) disable iff (!rst_n)
                            integrity_OK && !(|dut_temp_dirty) && dut_en_pending);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 5 (contract D1-D4, B2):
         Keys and the enable path.
           - disable_armed rises only on DISABLE_KEY_ID written to 0x40, and
             unlock_armed only on WRITE_ACCESS_KEY_ID written to 0x4F.
           - Each key falls only at a transaction end, at arm-timer expiry, or
             on a write to its own address (or CONTROL, for disable_armed).
           - A saturated arm timer disarms both keys on the next clock.
           - spi_enable moves in exactly three ways after reset: a commit with
             a pending CONTROL write, the watchdog, the physical switch.
           - It falls only on a commit of a pending DISABLE, and a pending
             disable is recorded only from a CONTROL write made while
             disable_armed was set - so no host disable without the key.
           - The physical switch wins: en_switch_rise forces spi_enable high
             on the next clock.
*/

property p_disable_key_rises_only_on_key;
  @(posedge clk) disable iff (!rst_n)
    $rose(dut_disable_armed)
        |-> $past(wr_en && (addr == ADDR_DISABLE_KEY) && (wdata == DISABLE_KEY_ID));
endproperty

a_disable_key_rises_only_on_key: assert property (p_disable_key_rises_only_on_key)
  else begin
    sva_pkg::note_failure("a_disable_key_rises_only_on_key: disable_armed set without the disable key");
  end

property p_unlock_key_rises_only_on_key;
  @(posedge clk) disable iff (!rst_n)
    $rose(dut_unlock_armed)
        |-> $past(wr_en && (addr == ADDR_WRITE_KEY) && (wdata == WRITE_ACCESS_KEY_ID));
endproperty

a_unlock_key_rises_only_on_key: assert property (p_unlock_key_rises_only_on_key)
  else begin
    sva_pkg::note_failure("a_unlock_key_rises_only_on_key: unlock_armed set without the write key");
  end

property p_disable_key_falls_known_ways;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $fell(dut_disable_armed))
        |-> $past(integrity_OK || txn_abort || (&dut_arm_timer)
                  || (wr_en && ((addr == ADDR_CONTROL) || (addr == ADDR_DISABLE_KEY))));
endproperty

a_disable_key_falls_known_ways: assert property (p_disable_key_falls_known_ways)
  else begin
    sva_pkg::note_failure("a_disable_key_falls_known_ways: disable_armed cleared by something outside the contract");
  end

property p_unlock_key_falls_known_ways;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $fell(dut_unlock_armed))
        |-> $past(integrity_OK || txn_abort || (&dut_arm_timer)
                  || (wr_en && (addr == ADDR_WRITE_KEY)));
endproperty

a_unlock_key_falls_known_ways: assert property (p_unlock_key_falls_known_ways)
  else begin
    sva_pkg::note_failure("a_unlock_key_falls_known_ways: unlock_armed cleared by something outside the contract");
  end

property p_arm_timer_lapses_keys;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && (dut_disable_armed || dut_unlock_armed) && (&dut_arm_timer) && !wr_en)
        |=> (!dut_disable_armed && !dut_unlock_armed);
endproperty

a_arm_timer_lapses_keys: assert property (p_arm_timer_lapses_keys)
  else begin
    sva_pkg::note_failure("a_arm_timer_lapses_keys: a key stayed armed past the arm timeout");
  end

property p_enable_moves_known_ways;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !(integrity_OK && dut_en_pending) && !chk_wd_expired && !en_switch_rise)
        |=> $stable(spi_enable);
endproperty

a_enable_moves_known_ways: assert property (p_enable_moves_known_ways)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_enable_moves_known_ways: spi_enable went %0b -> %0b with no commit, watchdog or switch",
      $past(spi_enable), spi_enable));
  end

property p_enable_falls_only_on_keyed_disable;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $fell(spi_enable))
        |-> $past(integrity_OK && dut_en_pending && !dut_en_pending_val);
endproperty

a_enable_falls_only_on_keyed_disable: assert property (p_enable_falls_only_on_keyed_disable)
  else begin
    sva_pkg::note_failure("a_enable_falls_only_on_keyed_disable: spi_enable fell without a committed disable");
  end

property p_pending_disable_needs_key;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && dut_en_pending && !dut_en_pending_val
                  && !$past(dut_en_pending && !dut_en_pending_val))
        |-> $past(wr_en && (addr == ADDR_CONTROL) && !wdata[0] && dut_disable_armed);
endproperty

a_pending_disable_needs_key: assert property (p_pending_disable_needs_key)
  else begin
    sva_pkg::note_failure("a_pending_disable_needs_key: a disable was recorded without disable_armed");
  end

property p_switch_wins;
  @(posedge clk) disable iff (!rst_n)
    en_switch_rise |=> spi_enable;
endproperty

a_switch_wins: assert property (p_switch_wins)
  else begin
    sva_pkg::note_failure("a_switch_wins: spi_enable low on the clock after en_switch_rise");
  end

c_disable_armed:        cover property (@(posedge clk) disable iff (!rst_n) $rose(dut_disable_armed));
c_unlock_armed:         cover property (@(posedge clk) disable iff (!rst_n) $rose(dut_unlock_armed));
c_host_disable:         cover property (@(posedge clk) disable iff (!rst_n) $fell(spi_enable));
c_disable_without_key:  cover property (@(posedge clk) disable iff (!rst_n)
                            wr_en && (addr == ADDR_CONTROL) && !wdata[0] && !dut_disable_armed);
c_wrong_key_value:      cover property (@(posedge clk) disable iff (!rst_n)
                            wr_en && (((addr == ADDR_DISABLE_KEY) && (wdata != DISABLE_KEY_ID))
                                   || ((addr == ADDR_WRITE_KEY)   && (wdata != WRITE_ACCESS_KEY_ID))));
c_arm_lapse:            cover property (@(posedge clk) disable iff (!rst_n)
                            (dut_disable_armed || dut_unlock_armed) && (&dut_arm_timer));
c_switch_while_vetoed:  cover property (@(posedge clk) disable iff (!rst_n)
                            en_switch_rise && !spi_enable);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 6 (contract E2-E4):
         The bus-silence watchdog.
           - Once the veto has been held for WD_TIMEOUT_MS with no valid write,
             the next clock has spi_enable high and wd_restored set (unless a
             commit lands on that same clock).
           - wd_restored rises only from the watchdog, and falls only on a
             committed host disable.
           - While the veto is held, the watchdog mark moves only on
             integrity_OK: reads do not prove the host is alive, writes do.
         Considered and subsumed: contract E1 (wd_expired only while the veto
         is held) is the definition of chk_wd_expired.
*/

property p_watchdog_restores;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && chk_wd_expired && !integrity_OK)
        |=> (spi_enable && dut_wd_restored);
endproperty

a_watchdog_restores: assert property (p_watchdog_restores)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_watchdog_restores: veto expired but en=%0b restored=%0b", spi_enable, dut_wd_restored));
  end

property p_wd_restored_rises_only_on_expiry;
  @(posedge clk) disable iff (!rst_n)
    $rose(dut_wd_restored) |-> $past(chk_wd_expired);
endproperty

a_wd_restored_rises_only_on_expiry: assert property (p_wd_restored_rises_only_on_expiry)
  else begin
    sva_pkg::note_failure("a_wd_restored_rises_only_on_expiry: wd_restored set without the watchdog expiring");
  end

property p_wd_restored_falls_only_on_host_disable;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && $fell(dut_wd_restored))
        |-> $past(integrity_OK && dut_en_pending && !dut_en_pending_val);
endproperty

a_wd_restored_falls_only_on_host_disable: assert property (p_wd_restored_falls_only_on_host_disable)
  else begin
    sva_pkg::note_failure("a_wd_restored_falls_only_on_host_disable: wd_restored cleared without a host disable");
  end

property p_veto_mark_moves_only_on_write;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !spi_enable && !integrity_OK) |=> $stable(dut_wd_mark);
endproperty

a_veto_mark_moves_only_on_write: assert property (p_veto_mark_moves_only_on_write)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_veto_mark_moves_only_on_write: wd_mark moved %0d -> %0d while the veto was held, with no write",
      $past(dut_wd_mark), dut_wd_mark));
  end

c_wd_expired:          cover property (@(posedge clk) disable iff (!rst_n) chk_wd_expired);
c_wd_restored_cleared: cover property (@(posedge clk) disable iff (!rst_n) $fell(dut_wd_restored));
c_heartbeat_in_veto:   cover property (@(posedge clk) disable iff (!rst_n) integrity_OK && !spi_enable);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 7 (contract F1, F2, F4, F6):
         The read port.
           - Unmapped addresses read 0x00.
           - PMIC_ID, VERSION and CAPABILITY read their fixed values.
           - The timestamp snapshot moves only on rd_first, and then takes the
             live counter.
           - fault_reg_read_done pulses exactly on the read of 0x20, the top
             of the fault record, and never otherwise.
         Every other mapped address, the STATUS packing and the coherence of
         a timestamp burst are M claims for the scoreboard.
*/

property p_unmapped_reads_zero;
  @(posedge clk) disable iff (!rst_n)
    !chk_addr_mapped |-> (rdata == 8'h00);
endproperty

a_unmapped_reads_zero: assert property (p_unmapped_reads_zero)
  else begin
    sva_pkg::note_failure($sformatf("a_unmapped_reads_zero: addr %0h read %0h", addr, rdata));
  end

property p_identity_bytes;
  @(posedge clk) disable iff (!rst_n)
    ((addr != ADDR_PMIC_ID)    || (rdata == PMIC_ID))
 && ((addr != ADDR_VERSION)    || (rdata == VERSION_ID))
 && ((addr != ADDR_CAPABILITY) || (rdata == CAPABILITY_VAL));
endproperty

a_identity_bytes: assert property (p_identity_bytes)
  else begin
    sva_pkg::note_failure($sformatf("a_identity_bytes: addr %0h read %0h", addr, rdata));
  end

property p_snapshot_moves_only_on_rd_first;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !rd_first) |=> $stable(dut_timestamp_snap);
endproperty

a_snapshot_moves_only_on_rd_first: assert property (p_snapshot_moves_only_on_rd_first)
  else begin
    sva_pkg::note_failure("a_snapshot_moves_only_on_rd_first: timestamp_snap changed without rd_first");
  end

property p_snapshot_takes_live_time;
  @(posedge clk) disable iff (!rst_n)
    rd_first |=> (dut_timestamp_snap == $past(timestamp_ms));
endproperty

a_snapshot_takes_live_time: assert property (p_snapshot_takes_live_time)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_snapshot_takes_live_time: snapshot %0d, counter was %0d", dut_timestamp_snap, $past(timestamp_ms)));
  end

property p_fault_clear_exact;
  @(posedge clk) disable iff (!rst_n)
    (fault_reg_read_done == (rd_byte_done && (addr == ADDR_FTIME_2)));
endproperty

a_fault_clear_exact: assert property (p_fault_clear_exact)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_fault_clear_exact: fault_reg_read_done=%0b with rd_byte_done=%0b addr=%0h",
      fault_reg_read_done, rd_byte_done, addr));
  end

c_unmapped_read:   cover property (@(posedge clk) disable iff (!rst_n) rd_byte_done && !chk_addr_mapped);
c_snapshot:        cover property (@(posedge clk) disable iff (!rst_n) rd_first);
c_fault_cleared:   cover property (@(posedge clk) disable iff (!rst_n) fault_reg_read_done);

/*
////////////////////////////////////////////////////////////////////////////////
*/

/*
Purpose: PAC(Property, Assertion, Cover) Group 8 (contract G1):
         The bus-error counter.
           - It moves only on txn_abort.
           - Each txn_abort adds exactly one.
           - It holds at 0xFFFF rather than wrapping.
*/

property p_bus_err_moves_only_on_abort;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && !txn_abort) |=> $stable(dut_bus_err_count);
endproperty

a_bus_err_moves_only_on_abort: assert property (p_bus_err_moves_only_on_abort)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_bus_err_moves_only_on_abort: count went %0d -> %0d with no txn_abort",
      $past(dut_bus_err_count), dut_bus_err_count));
  end

property p_bus_err_counts_one;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && txn_abort && (dut_bus_err_count != 16'hFFFF))
        |=> (dut_bus_err_count == ($past(dut_bus_err_count) + 16'd1));
endproperty

a_bus_err_counts_one: assert property (p_bus_err_counts_one)
  else begin
    sva_pkg::note_failure($sformatf(
      "a_bus_err_counts_one: count went %0d -> %0d on one txn_abort",
      $past(dut_bus_err_count), dut_bus_err_count));
  end

property p_bus_err_saturates;
  @(posedge clk) disable iff (!rst_n)
    ($past(rst_n) && txn_abort && (dut_bus_err_count == 16'hFFFF))
        |=> (dut_bus_err_count == 16'hFFFF);
endproperty

a_bus_err_saturates: assert property (p_bus_err_saturates)
  else begin
    sva_pkg::note_failure($sformatf("a_bus_err_saturates: count wrapped to %0d", dut_bus_err_count));
  end

c_bus_err_counted:   cover property (@(posedge clk) disable iff (!rst_n) txn_abort);
c_bus_err_saturated: cover property (@(posedge clk) disable iff (!rst_n)
                         txn_abort && (dut_bus_err_count == 16'hFFFF));

/*
////////////////////////////////////////////////////////////////////////////////
*/

endmodule

`default_nettype wire

