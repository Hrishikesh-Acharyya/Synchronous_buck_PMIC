#
# Filename:         report.tcl
#
# File Description: Post-route reports for one run directory: reads final.odb,
#                   extracts parasitics from the routed wires with OpenRCX, and
#                   reports worst setup and hold slack at 10 MHz, the critical
#                   paths, clock skew, power (default switching activity) and
#                   area. Appends its numbers to the run's metrics.txt.
#
# Global variables: Environment - RUN (run directory).


set plat platform
set run  $::env(RUN)
set mf [open $run/metrics.txt a]
proc metric {k v} { global mf; puts $mf "$k = $v"; flush $mf; puts "METRIC $k = $v" }
proc stamp {what} { puts "STAMP [clock format [clock seconds] -format %T] $what" }

stamp read
read_db $run/final.odb
read_liberty $plat/sky130_fd_sc_hd__tt_025C_1v80.lib
read_sdc $run/final.sdc
source $plat/setRC.tcl
set_propagated_clock [all_clocks]

stamp extract
if {[catch {
    define_process_corner -ext_model_index 0 X
    extract_parasitics -ext_model_file $plat/rcx_patterns.rules
    write_spef $run/final.spef
    read_spef $run/final.spef
    metric parasitics "OpenRCX from routed wires"
} err]} {
    puts "extraction failed: $err - falling back to placement estimates"
    estimate_parasitics -placement
    metric parasitics "placement estimate (extraction failed)"
}

stamp worst_slack
report_worst_slack -max -digits 3 > $run/ws_max.rpt
report_worst_slack -min -digits 3 > $run/ws_min.rpt
foreach {f k} [list $run/ws_max.rpt worst_setup_slack_ns $run/ws_min.rpt worst_hold_slack_ns] {
    set fh [open $f]; set t [read $fh]; close $fh
    if {[regexp {worst slack\s+(-?[0-9.]+)} $t -> v]} { metric $k $v }
}
metric tns_setup_ns [format %.3f [sta::total_negative_slack_cmd max]]
stamp report_checks_max
report_checks -path_delay max -fields {slew cap fanout} -digits 3 > $run/timing_max.rpt
stamp report_checks_min
report_checks -path_delay min -digits 3 > $run/timing_min.rpt
stamp skew
catch {report_clock_skew > $run/skew.rpt}
stamp power
catch {report_power > $run/power.rpt}
stamp area
report_design_area
stamp done
close $mf
exit 0
