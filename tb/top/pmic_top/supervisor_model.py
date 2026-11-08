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
#                   strike_counter.sv, fault_LED.sv, pgood_gen.sv and
#                   pmic_top.sv (headers and Purpose blocks). Timing within a
#                   transition is not modelled - the bound checkers own that.
#
# Global variables: S_OFF, S_SS, S_RUN, S_HICCUP - state encodings

from top_constants import MAX_STRIKES, FAST_CLEAN_RUN_MS

# S_*: supervisor state_t encoding (pmic_types_pkg.sv), as STATUS[1:0] reads it
S_OFF, S_SS, S_RUN, S_HICCUP = 0, 1, 2, 3


class SupervisorModel():

    """
    Purpose: The board's knobs, the latch, the strike count and the time spent
             running clean; predict() turns them into expected pin and STATUS
             values. One instance per test, created right after reset.
    """

    def __init__(self):

        """
        Purpose: Reset state, with the board idle: switch off, no faults, rail
                 good, host enable at its reset value.
        """
        self.switch      = 0      # enable switch, as the board drives it
        self.host_enable = 1      # reg_file spi_enable: resets high
        self.otp         = 0
        self.uvlo        = 0
        self.pgood_comp  = 1      # rail in its window whenever it is switching
        self.scr         = 0      # SCR latch on the board
        self.latch_out   = 0      # strike counter's trip into the SCR
        self.strikes     = 0      # strike_level
        self.clean_ms    = 0      # time in S_RUN since the last strike
        self.run_ms      = 0      # time in S_RUN since the last entry

    # ---- derived ----

    def allowed(self):

        """
        Purpose: Every enable given and no hard fault live - the condition for
                 the supervisor to leave S_OFF and stay out of it.
        """
        return (self.switch and self.host_enable and not self.otp and not self.uvlo
                and not self.scr and not self.latch_out)

    def state(self):

        """
        Purpose: The state the converter settles in. With no overcurrent
                 pending, an allowed converter ends in S_RUN and any other in
                 S_OFF; overcurrent outcomes are applied by the event methods.
        """
        return S_RUN if self.allowed() else S_OFF

    # ---- events ----

    def set_switch(self, on):
        self.switch = int(on)
        self._left_run_if_stopped()

    def set_host_enable(self, on):
        self.host_enable = int(on)
        self._left_run_if_stopped()

    def set_otp(self, on):
        self.otp = int(on)
        self._left_run_if_stopped()

    def set_uvlo(self, on):
        self.uvlo = int(on)
        self._left_run_if_stopped()

    def set_pgood_comp(self, good):
        self.pgood_comp = int(good)

    def ovp_trip(self):

        """
        Purpose: The analog OVP comparator trips the SCR. The CPLD did not
                 trip it, so latch_out stays low; the read-back stops the
                 converter.
        """
        self.scr = 1
        self._left_run_if_stopped()

    def overcurrent_trip(self):

        """
        Purpose: One overcurrent episode that trips the window once and clears
                 before the retry: one strike, a hiccup, and back to S_RUN -
                 unless this strike reaches MAX_STRIKES, which trips the latch.
                 Only meaningful while the converter is allowed to run.
        """
        if not self.allowed():
            return
        self.strikes = min(self.strikes + 1, 3)
        self.clean_ms = 0
        self.run_ms = 0
        if self.strikes >= MAX_STRIKES:
            self.latch_out = 1
            self.scr = 1

    def persistent_overcurrent(self):

        """
        Purpose: An overcurrent that never clears: every retry trips again
                 until the strike count reaches MAX_STRIKES and the latch trips.
        """
        while self.allowed():
            self.overcurrent_trip()

    def reset_button(self):

        """
        Purpose: The board's reset button: resets the CPLD and drains the SCR.
                 Everything returns to reset values except the board knobs,
                 which are physical.
        """
        board = (self.switch, self.otp, self.uvlo, self.pgood_comp)
        self.__init__()
        self.switch, self.otp, self.uvlo, self.pgood_comp = board

    def elapse(self, ms):

        """
        Purpose: Time passes with the board steady. Running time counts toward
                 PGOOD and toward the clean-run window that clears the strikes.
        """
        if self.state() == S_RUN:
            self.run_ms += ms
            self.clean_ms += ms
            if self.clean_ms >= FAST_CLEAN_RUN_MS:
                self.strikes = 0

    def _left_run_if_stopped(self):
        if not self.allowed():
            self.run_ms = 0
            self.clean_ms = 0

    # ---- predictions ----

    def predict(self, pgood_settled):

        """
        Purpose: Expected pin values and STATUS fields in the settled state.
                 pgood_settled says whether the test waited out the PGOOD
                 qualification since the converter last entered S_RUN.
        """
        state   = self.state()
        running = state == S_RUN
        pgood   = int(running and self.pgood_comp and pgood_settled)
        latched = int(self.scr or self.latch_out)
        return {
            "En":            int(running),
            "PGOOD":         pgood,
            "switch_supply": pgood,
            "pgood_LED":     pgood,
            "Green_LED":     int(running),
            "latch_out":     self.latch_out,
            "latch_stat":    self.scr,
            "Red_LED2":      self.otp,
            "Red_LED3":      self.uvlo,
            # Red_LED1: solid on a latch, blinking while strikes are outstanding
            "Red_LED1":      "solid" if latched else ("blink" if self.strikes else "off"),
            "state":         state,
            "strikes":       self.strikes,
        }
