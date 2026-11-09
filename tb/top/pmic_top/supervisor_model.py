#
# Filename:         supervisor_model.py
#
# File Description: Reference model of the whole supervisor, at the level of
#                   SETTLED outcomes: given the board's knobs and the history
#                   of faults, which state the converter rests in once every
#                   debounce, ramp, trip and cool-down has played out, and
#                   what every status pin and STATUS bit then shows. Tests
#                   apply an event to the board and to the model, wait the
#                   event's settle time, and compare.
#
#                   Written from the documented contracts of supervisor.sv,
#                   strike_counter.sv, hiccup_timer.sv, fault_LED.sv,
#                   pgood_gen.sv, input_debounce.sv and pmic_top.sv (headers
#                   and Purpose blocks). Timing within a transition is not
#                   modelled - the bound checkers own that - but the model
#                   does keep simulation time, so it knows when the converter
#                   entered S_RUN: each enabling input becomes effective after
#                   its own debounce, and the ramp follows the last of them.
#                   From that it predicts PGOOD (9 ms of good rail in S_RUN)
#                   and the clean-run clear of the strikes; within
#                   BOUNDARY_MARGIN_MS of either boundary the outcome is
#                   reported as unknown (None) and the check skips it.
#
# Global variables: S_OFF, S_SS, S_RUN, S_HICCUP - state encodings

from cocotb.utils import get_sim_time

from top_constants import (MAX_STRIKES, FAST_HICCUP_MS, FAST_CYCLES_PER_STEP, FAST_CLEAN_RUN,
                           CYCLE_MS, MAX_ON_COUNTS, MIN_ON_COUNTS, SWITCH_DEBOUNCE_MS,
                           FAULT_ASSERT_MS, FAULT_RELEASE_MS, PGOOD_DELAY_EXACT_MS,
                           DEFAULT_HICCUP_MS, DEFAULT_CYCLES_PER_STEP, DEFAULT_CLEAN_RUN_MS,
                           BOUNDARY_MARGIN_MS)

# S_*: supervisor state_t encoding (pmic_types_pkg.sv), as STATUS[1:0] reads it
S_OFF, S_SS, S_RUN, S_HICCUP = 0, 1, 2, 3


def sim_ms():

    """
    Purpose: Current simulation time in ms - the model's clock.
    """
    return get_sim_time("ns") / 1_000_000


class SupervisorModel():

    """
    Purpose: The board's knobs, the latch, the strike count, the timers in
             force, and when each enabling input last became effective;
             predict() turns them into expected pin and STATUS values. One
             instance per test, created right after reset.
    """

    def __init__(self, clock=sim_ms):

        """
        Purpose: Reset state, with the board idle: switch off, no faults, rail
                 good, host enable at its reset value, every timer at its
                 reset value.
        """
        self.clock       = clock
        self.switch      = 0      # enable switch, as the board drives it
        self.host_enable = 1      # reg_file spi_enable: resets high
        self.otp         = 0
        self.uvlo        = 0
        self.pgood_comp  = 1      # rail in its window whenever it is switching
        self.scr         = 0      # SCR latch on the board
        self.latch_out   = 0      # strike counter's trip into the SCR
        self.strikes     = 0      # strike_level
        self.max_strikes = MAX_STRIKES
        self.default_timers()
        now = self.clock()
        # ready_at: when each enabling input's present level became (or
        #           becomes) effective past its debounce
        self.ready_at     = {"switch": now, "host": now, "otp": now, "uvlo": now}
        # run_entry: when the converter entered (or will enter) S_RUN; None
        #            while it is not allowed to run
        self.run_entry    = None
        # rail_good_at: when the rail comparator last returned to good
        self.rail_good_at = now

    # ---- timers ----

    def default_timers(self):

        """
        Purpose: The S_OFF-only timers' reset values: 5 ms hiccup base, 16
                 cycles per ramp step, a 1 s clean-run window.
        """
        self.hiccup_base_ms  = DEFAULT_HICCUP_MS
        self.cycles_per_step = DEFAULT_CYCLES_PER_STEP
        self.clean_run_ms    = DEFAULT_CLEAN_RUN_MS

    def fast_timers(self):

        """
        Purpose: The timers configure_fast_timers programs, with MAX_STRIKES
                 back at its reset value (the bank write includes it).
        """
        self.hiccup_base_ms  = FAST_HICCUP_MS
        self.cycles_per_step = FAST_CYCLES_PER_STEP
        self.clean_run_ms    = FAST_CLEAN_RUN * CYCLE_MS
        self.max_strikes     = MAX_STRIKES
        # programmed in S_OFF, so a start still pending ramps at the new rate
        if self.run_entry is not None and self.run_entry > self.clock():
            self.run_entry = max(self.ready_at.values()) + self.ramp_ms()

    def ramp_ms(self):

        """
        Purpose: Soft-start length: one step per cycles_per_step switching
                 cycles from the floor to the ceiling, plus one cycle of slack.
        """
        return ((MAX_ON_COUNTS - MIN_ON_COUNTS) * self.cycles_per_step + 1) * CYCLE_MS

    def hiccup_ms(self, level):

        """
        Purpose: Cool-down at a strike level: base doubled per strike - the
                 level after the increment, so 2 x and 4 x the base.
        """
        return self.hiccup_base_ms * (1 << level)

    # ---- derived ----

    def allowed(self):

        """
        Purpose: Every enable given and no hard fault live - the condition for
                 the supervisor to leave S_OFF and stay out of it.
        """
        return bool(self.switch and self.host_enable and not self.otp and not self.uvlo
                    and not self.scr and not self.latch_out)

    def latched(self):
        return bool(self.scr or self.latch_out)

    def state(self):

        """
        Purpose: The state the converter is in. Not allowed: S_OFF. Allowed:
                 S_RUN once the RUN entry time has passed; before it, S_OFF
                 while an enabling input is still inside its debounce, and
                 None (soft start or a cool-down - not called) after that.
                 Overcurrent outcomes are applied by the event methods.
        """
        if not self.allowed():
            return S_OFF
        now = self.clock()
        if self.run_entry is None or now >= self.run_entry:
            return S_RUN
        if now < max(self.ready_at.values()):
            return S_OFF
        return None

    def switch_seen(self):

        """
        Purpose: The switch as the design sees it past its 20 ms debounce, or
                 None while a change is still inside it.
        """
        return self.switch if self.clock() >= self.ready_at["switch"] else None

    def settle_needed(self):

        """
        Purpose: How much longer, in ms, until the converter has reached S_RUN
                 with margin, if it is on its way there; 0 otherwise.
        """
        if self.run_entry is None:
            return 0
        return max(0.0, self.run_entry + 0.3 - self.clock())

    # ---- time ----

    def _sync(self):

        """
        Purpose: Apply what time alone does: a clean run as long as the window
                 clears the strikes. Called before every event and prediction.
        """
        if self.run_entry is not None and self.strikes and not self.latched():
            if self.clock() - self.run_entry >= self.clean_run_ms + BOUNDARY_MARGIN_MS:
                self.strikes = 0

    def clean_run_uncertain(self):

        """
        Purpose: Whether the clean-run window is too close to call: the
                 strikes may or may not have been cleared yet.
        """
        if self.run_entry is None or not self.strikes or self.latched():
            return False
        elapsed = self.clock() - self.run_entry
        return abs(elapsed - self.clean_run_ms) < BOUNDARY_MARGIN_MS

    def margin_to_certainty(self):

        """
        Purpose: How long to wait, in ms, before the strike count is certain
                 again - for an event whose outcome depends on it.
        """
        if not self.clean_run_uncertain():
            return 0
        return self.run_entry + self.clean_run_ms + BOUNDARY_MARGIN_MS - self.clock() + 0.05

    def elapse(self, ms):

        """
        Purpose: Time passes with the board steady. Kept for the tests' wait
                 helper; the model reads simulation time itself.
        """
        self._sync()

    # ---- events ----

    def _changed(self):

        """
        Purpose: After an input change: if the converter has just become
                 allowed, it enters S_RUN once the last enabling input is
                 effective and the ramp has run; if it is no longer allowed,
                 it is off.
        """
        if not self.allowed():
            self.run_entry = None
        elif self.run_entry is None:
            self.run_entry = max(self.ready_at.values()) + self.ramp_ms()

    def set_switch(self, on):
        self._sync()
        if int(on) != self.switch:
            self.ready_at["switch"] = self.clock() + SWITCH_DEBOUNCE_MS
        self.switch = int(on)
        self._changed()

    def set_host_enable(self, on):
        self._sync()
        self.host_enable = int(on)
        self.ready_at["host"] = self.clock()
        self._changed()

    def set_otp(self, on):
        self._sync()
        if int(on) != self.otp:
            self.ready_at["otp"] = self.clock() + (FAULT_ASSERT_MS if on else FAULT_RELEASE_MS)
        self.otp = int(on)
        self._changed()

    def set_uvlo(self, on):
        self._sync()
        if int(on) != self.uvlo:
            self.ready_at["uvlo"] = self.clock() + (FAULT_ASSERT_MS if on else FAULT_RELEASE_MS)
        self.uvlo = int(on)
        self._changed()

    def set_pgood_comp(self, good):
        self._sync()
        if int(good) and not self.pgood_comp:
            self.rail_good_at = self.clock()
        self.pgood_comp = int(good)

    def set_max_strikes(self, raw):

        """
        Purpose: A live MAX_STRIKES write, clamped as reg_file does: 1 to 3.
                 Takes effect on the next hiccup entry, not at once.
        """
        self._sync()
        self.max_strikes = min(max(raw, 1), MAX_STRIKES)

    def ramp_restarted(self):

        """
        Purpose: The ramp starts now rather than when the enables last allowed
                 it - for a test that held soft start up (a stopped
                 modulator) and has just released it.
        """
        self._sync()
        if self.allowed():
            self.run_entry = self.clock() + self.ramp_ms()

    def ovp_trip(self):

        """
        Purpose: The analog OVP comparator trips the SCR. The CPLD did not
                 trip it, so latch_out stays low; the read-back stops the
                 converter.
        """
        self._sync()
        self.scr = 1
        self._changed()

    def overcurrent_trip(self):

        """
        Purpose: One overcurrent episode that trips the window once and clears
                 before the retry: one strike, a hiccup, and back to S_RUN -
                 unless this strike reaches MAX_STRIKES, which trips the latch.
                 Only meaningful while the converter is running. Returns the
                 hiccup's length in ms, or 0 when the strike latched (or the
                 converter was not running).
        """
        self._sync()
        if not self.allowed():
            return 0
        self.strikes = min(self.strikes + 1, 3)
        if self.strikes >= self.max_strikes:
            self.latch_out = 1
            self.scr = 1
            self.run_entry = None
            return 0
        cool_down = self.hiccup_ms(self.strikes)
        self.run_entry = self.clock() + cool_down + self.ramp_ms()
        return cool_down

    def persistent_overcurrent(self):

        """
        Purpose: An overcurrent that never clears: every retry trips again
                 until the strike count reaches MAX_STRIKES and the latch trips.
                 Returns the total cool-down time on the way, in ms.
        """
        total = 0
        while self.allowed():
            total += self.overcurrent_trip()
        return total

    def reset_button(self):

        """
        Purpose: The board's reset button: resets the CPLD and drains the SCR.
                 Everything returns to reset values except the board knobs,
                 which are physical. The switch debouncer restarts from off,
                 and the fault flags from asserted.
        """
        board = (self.switch, self.otp, self.uvlo, self.pgood_comp)
        self.__init__(self.clock)
        self.switch, self.otp, self.uvlo, self.pgood_comp = board
        now = self.clock()
        self.ready_at["switch"] = now + (SWITCH_DEBOUNCE_MS if self.switch else 0)
        self.ready_at["otp"]    = now + FAULT_RELEASE_MS
        self.ready_at["uvlo"]   = now + FAULT_RELEASE_MS
        self._changed()

    # ---- predictions ----

    def pgood_expected(self):

        """
        Purpose: PGOOD from time: in S_RUN with the rail good for the
                 qualification time since the later of RUN entry and the
                 rail's return. None within the boundary margin.
        """
        if self.state() != S_RUN or not self.pgood_comp:
            return 0
        good_for = self.clock() - max(self.run_entry, self.rail_good_at)
        if abs(good_for - PGOOD_DELAY_EXACT_MS) < BOUNDARY_MARGIN_MS:
            return None
        return int(good_for >= PGOOD_DELAY_EXACT_MS)

    def predict(self, pgood_settled=None):

        """
        Purpose: Expected pin values and STATUS fields in the settled state.
                 pgood_settled, if given, overrides the timed PGOOD
                 prediction: True says the test waited out the qualification
                 since the converter last entered S_RUN, False that it did
                 not. A field the model cannot call is None.
        """
        self._sync()
        state   = self.state()
        running = state == S_RUN
        on      = None if state is None else int(running)
        if pgood_settled is None:
            pgood = self.pgood_expected()
        else:
            pgood = int(running and self.pgood_comp and pgood_settled)
        latched = self.latched()
        strikes = None if self.clean_run_uncertain() else self.strikes
        if latched:
            red1 = "solid"
        elif strikes is None:
            red1 = None
        else:
            red1 = "blink" if strikes else "off"
        return {
            "En":            on,
            "PGOOD":         pgood,
            "switch_supply": pgood,
            "pgood_LED":     pgood,
            "Green_LED":     on,
            "latch_out":     self.latch_out,
            "latch_stat":    self.scr,
            "Red_LED2":      self.otp,
            "Red_LED3":      self.uvlo,
            # Red_LED1: solid on a latch, blinking while strikes are outstanding
            "Red_LED1":      red1,
            "state":         state,
            "strikes":       strikes,
        }
