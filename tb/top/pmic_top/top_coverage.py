#
# Filename:         top_coverage.py
#
# File Description: Functional coverage for the whole supervisor, with
#                   cocotb-coverage. Sampled by random_walk from the model's
#                   view of each event - what the event was, what the
#                   converter was doing when it came, and what it led to:
#                     pmic_top.event    every event kind from every condition
#                                       (off, running, latched)
#                     pmic_top.stop     every way the converter stops, from
#                                       S_RUN and from the middle of a hiccup
#                     pmic_top.strike   every strike level reached under every
#                                       MAX_STRIKES limit, and whether it latched
#                     pmic_top.recovery every way a stopped converter comes back
#                     pmic_top.latch    who tripped the SCR, running or off
#                     pmic_top.filter   every glitch the debouncers must reject,
#                                       against a settled input and mid-debounce
#                     pmic_top.pgood    PGOOD qualified, dropped by the rail,
#                                       dropped by leaving S_RUN
#                   The SVA covers say a scenario happened at signal level;
#                   these say which combinations of board-level MEANING the
#                   random walk reached. Named apart from host_if's
#                   functional_coverage.py, which is on the same PYTHONPATH.
#
# Global variables: EVENT_KINDS, CONDITIONS, STOP_CAUSES, STOP_FROM, STRIKE_LEVELS,
#                   RECOVERY_PATHS, LATCH_SOURCES, GLITCH_KINDS, PGOOD_EDGES

from cocotb_coverage.coverage import CoverPoint, CoverCross, coverage_db

# EVENT_KINDS: random_walk's events (see its docstring)
EVENT_KINDS    = ["switch", "otp", "uvlo", "host", "trip", "persist", "ovp", "reset",
                  "rail", "wait", "thresholds", "glitch", "fault_in_hiccup", "clean_run"]
# CONDITIONS: the converter's settled condition when an event arrives
CONDITIONS     = ["off", "running", "latched"]
# STOP_CAUSES: what took a running converter to S_OFF
STOP_CAUSES    = ["switch", "host", "otp", "uvlo", "ovp", "strike_latch", "reset"]
# STOP_FROM: where the converter was when the stop came - regulating, or in a
#            cool-down after a trip
STOP_FROM      = ["run", "hiccup"]
# STRIKE_LEVELS / MAX_LIMITS: strike_level after a trip, and MAX_STRIKES in force
STRIKE_LEVELS  = [1, 2, 3]
MAX_LIMITS     = [1, 2, 3]
# RECOVERY_PATHS: how a stopped or struck converter returned to normal;
#                 switch_over_host is a switch turn-on that also cancelled a
#                 host disable
RECOVERY_PATHS = ["hiccup_retry", "fault_cleared", "host_enable", "switch_on", "reset_button",
                  "strikes_forgotten", "switch_over_host"]
# LATCH_SOURCES / LATCH_WHEN: who tripped the SCR, and whether the converter
#                             was running
LATCH_SOURCES  = ["strikes", "ovp"]
LATCH_WHEN     = ["running", "off"]
# GLITCH_KINDS: sub-debounce disturbances random_walk applies without telling
#               the model
GLITCH_KINDS   = ["otp_pulse", "uvlo_pulse", "otp_dropout", "uvlo_dropout", "switch_blip"]
# PGOOD_EDGES: PGOOD changes seen between two checks
PGOOD_EDGES    = ["qualified", "rail_drop", "left_run"]

# the events that need a running converter, so are never drawn otherwise
_RUNNING_ONLY = ["persist", "fault_in_hiccup", "clean_run"]


@CoverPoint("pmic_top.event.kind",      xf=lambda kind, condition: kind,      bins=EVENT_KINDS)
@CoverPoint("pmic_top.event.condition", xf=lambda kind, condition: condition, bins=CONDITIONS)
@CoverCross("pmic_top.event.kind_x_condition",
            items=["pmic_top.event.kind", "pmic_top.event.condition"],
            ign_bins=[(kind, condition) for kind in _RUNNING_ONLY
                      for condition in ["off", "latched"]])
def sample_event(kind, condition):

    """
    Purpose: Sample one random_walk event and the condition it arrived in.
             The decorators do the counting; the body is empty.
    """
    pass


@CoverPoint("pmic_top.stop.cause", xf=lambda cause, where: cause, bins=STOP_CAUSES)
@CoverPoint("pmic_top.stop.from",  xf=lambda cause, where: where, bins=STOP_FROM)
@CoverCross("pmic_top.stop.cause_x_from",
            items=["pmic_top.stop.cause", "pmic_top.stop.from"],
            # the switch's 20 ms debounce outlasts every cool-down, and a
            # strike latches on hiccup ENTRY - neither can land mid-hiccup
            ign_bins=[("switch", "hiccup"), ("strike_latch", "hiccup")])
def sample_stop(cause, where):

    """
    Purpose: Sample one stop: what stopped the converter, and from where.
    """
    pass


@CoverPoint("pmic_top.strike.level",   xf=lambda level, limit, latched: level,   bins=STRIKE_LEVELS)
@CoverPoint("pmic_top.strike.limit",   xf=lambda level, limit, latched: limit,   bins=MAX_LIMITS)
@CoverPoint("pmic_top.strike.latched", xf=lambda level, limit, latched: latched, bins=[False, True])
@CoverCross("pmic_top.strike.level_x_limit",
            items=["pmic_top.strike.level", "pmic_top.strike.limit"],
            # a strike at or past the limit latches, so no level goes further
            ign_bins=[(2, 1), (3, 1), (3, 2)])
def sample_strike(level, limit, latched):

    """
    Purpose: Sample one strike: the level it reached, the limit in force, and
             whether it tripped the latch.
    """
    pass


@CoverPoint("pmic_top.recovery.path", xf=lambda path: path, bins=RECOVERY_PATHS)
def sample_recovery(path):

    """
    Purpose: Sample one recovery: how the converter came back to S_RUN, or
             shed its strikes.
    """
    pass


@CoverPoint("pmic_top.latch.source", xf=lambda source, when: source, bins=LATCH_SOURCES)
@CoverPoint("pmic_top.latch.when",   xf=lambda source, when: when,   bins=LATCH_WHEN)
@CoverCross("pmic_top.latch.source_x_when",
            items=["pmic_top.latch.source", "pmic_top.latch.when"],
            ign_bins=[("strikes", "off")])       # strikes are earned only while running
def sample_latch(source, when):

    """
    Purpose: Sample one SCR trip: by the CPLD's strike count or the analog
             OVP, and whether the converter was running.
    """
    pass


@CoverPoint("pmic_top.filter.glitch",  xf=lambda kind, pending: kind,    bins=GLITCH_KINDS)
@CoverPoint("pmic_top.filter.pending", xf=lambda kind, pending: pending, bins=[False, True])
def sample_glitch(kind, pending):

    """
    Purpose: Sample one sub-debounce glitch, and whether it caught that
             input's debounce in progress (and so restarted it).
    """
    pass


@CoverPoint("pmic_top.pgood.edge", xf=lambda edge: edge, bins=PGOOD_EDGES)
def sample_pgood(edge):

    """
    Purpose: Sample one PGOOD change and its reason.
    """
    pass


def report_coverage(log, xml_path=None):

    """
    Purpose: Log every covergroup with its bins and percentage, and
             optionally export the database to XML for merging across runs.
    """
    coverage_db.report_coverage(log.info, bins=True)
    if xml_path:
        coverage_db.export_to_xml(filename=xml_path)
