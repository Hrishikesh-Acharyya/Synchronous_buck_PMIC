#
# Filename:         functional_coverage.py
#
# File Description: Functional coverage for host_if, with cocotb-coverage.
#                   Two covergroups, sampled by random_walk from the outcomes
#                   the register model returns:
#                     host_if.threshold - why each threshold frame was accepted
#                                         or rejected, crossed with sup_state
#                     host_if.frame     - how each transaction ended
#                   The SVA covers say a scenario happened at signal level;
#                   these say which combinations of transaction MEANING the
#                   random stimulus reached.
#
# Global variables: THRESHOLD_REASONS, SUP_STATES, FRAME_ENDINGS, CLAMP_REGIONS

from cocotb_coverage.coverage import CoverPoint, CoverCross, coverage_db
from reg_file_model import THRESHOLD_BIODATA

# THRESHOLD_REASONS: RegfileModel.apply_write's verdict on a threshold frame;
#                    writeback is an acceptance outside S_OFF that passed
#                    through an S_OFF-only register with its present value
THRESHOLD_REASONS = ["accepted", "writeback", "no_key", "partial", "not_off"]
# SUP_STATES: sup_state encodings - OFF, SS, RUN, HICCUP
SUP_STATES        = [0, 1, 2, 3]
# FRAME_ENDINGS: RegfileModel.apply_frame's verdict, plus clean/bad_crc from random_write
FRAME_ENDINGS     = ["clean", "bad_crc", "cut_mid_byte", "short", "truncated_cmd",
                     "write_stall", "read", "read_cut", "read_stall"]

@CoverPoint("host_if.threshold.reason", xf=lambda reason, state: reason, bins=THRESHOLD_REASONS)
@CoverPoint("host_if.threshold.state",  xf=lambda reason, state: state,  bins=SUP_STATES)
@CoverCross("host_if.threshold.reason_x_state",
            items=["host_if.threshold.reason", "host_if.threshold.state"],
            # S_OFF-only refusals and write-backs exist only outside S_OFF
            ign_bins=[("not_off", 0), ("writeback", 0)])
def sample_threshold(reason, state):

    """
    Purpose: Sample one threshold frame's verdict and the supervisor state it
             arrived in. The decorators do the counting; the body is empty.
    """
    pass


@CoverPoint("host_if.frame.ending", xf=lambda ending: ending, bins=FRAME_ENDINGS)
def sample_frame(ending):

    """
    Purpose: Sample how one transaction ended.
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

# CLAMP_REGIONS: clamp_region's verdicts, low to high
CLAMP_REGIONS = ["below", "at_min", "inside", "at_max", "above"]


@CoverPoint("host_if.clamp.register", xf=lambda name, region: name,   bins=list(THRESHOLD_BIODATA))
@CoverPoint("host_if.clamp.region",   xf=lambda name, region: region, bins=CLAMP_REGIONS)
@CoverCross("host_if.clamp.register_x_region",
            items=["host_if.clamp.register", "host_if.clamp.region"])
def sample_clamp(name, region):

    """
    Purpose: Sample one committed threshold: which register, and which part of
             its range the written value fell in. The cross (7 x 5) shows every
             register committed below, at and between its bounds.
    """
    pass