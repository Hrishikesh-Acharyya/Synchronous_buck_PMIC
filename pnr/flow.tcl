#
# Filename:         flow.tcl
#
# File Description: Place and route of pmic_top in a fixed die with OpenROAD and
#                   sky130_fd_sc_hd: floorplan with a core margin, pins, tap
#                   cells, a met1/met4/met5 power grid, global and detailed
#                   placement, resizing and buffering, clock tree, setup and hold
#                   repair, global and detailed routing (TritonRoute), fillers.
#                   Saves the routed design; report.tcl reports from it.
#                   Run by run_pnr.sh from the pnr/ directory.
#
#                   Every input of pmic_top is asynchronous to clk and
#                   synchronised on chip, and the outputs drive slow off-chip
#                   parts, so only register-to-register paths are constrained
#                   (10 MHz).
#
# Global variables: Environment - NETLIST (gate-level netlist), DIE_W, DIE_H and
#                   MARGIN (um), OUT (run directory), DENSITY_ADD (placement
#                   density above the starting utilisation). Writes
#                   $OUT/metrics.txt as "key = value" lines.

set plat platform
set out  $::env(OUT)
set W    $::env(DIE_W)
set H    $::env(DIE_H)
set M    $::env(MARGIN)
set ::env(TAP_CELL_NAME)         sky130_fd_sc_hd__tapvpwrvgnd_1
set ::env(MIN_ROUTING_LAYER)     met1
set ::env(MIN_CLK_ROUTING_LAYER) met3
set ::env(MAX_ROUTING_LAYER)     met5

set mf [open $out/metrics.txt w]
proc metric {k v} { global mf; puts $mf "$k = $v"; flush $mf; puts "METRIC $k = $v" }

read_lef $plat/sky130_fd_sc_hd.tlef
read_lef $plat/sky130_fd_sc_hd_merged.lef
read_liberty $plat/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog $::env(NETLIST)
link_design pmic_top

# 10 MHz. Every input is asynchronous to clk and synchronised on chip, and the
# outputs go off chip to slow analog parts, so only register-to-register paths
# are constrained.
create_clock -name clk -period 100.0 [get_ports clk]
set async_in {}
foreach p [all_inputs] { if {[get_full_name $p] != "clk"} { lappend async_in $p } }
set_false_path -from $async_in
set_false_path -to [all_outputs]
source $plat/setRC.tcl

# ---- floorplan ----
initialize_floorplan -die_area "0 0 $W $H" \
    -core_area "$M $M [expr {$W - $M}] [expr {$H - $M}]" -site unithd
source $plat/make_tracks.tcl
place_pins -hor_layers met3 -ver_layers met2
tapcell -distance 14 -tapcell_master $::env(TAP_CELL_NAME)
source $plat/pdn.tcl
pdngen

set block [ord::get_db_block]
set dbu   [[ord::get_db_tech] getDbUnitsPerMicron]
proc cell_area {} {
    global block dbu
    set a 0.0
    foreach inst [$block getInsts] {
        set m [$inst getMaster]
        if {[$m getType] == "CORE_SPACER"} continue
        set a [expr {$a + double([$m getWidth]) * [$m getHeight]}]
    }
    return [expr {$a / ($dbu * $dbu)}]
}
set core [$block getCoreArea]
set core_area [expr {double([$core dx]) * [$core dy] / ($dbu * $dbu)}]
metric die_um "${W}x${H}"
metric die_area_um2 [format %.0f [expr {$W * $H}]]
metric core_area_um2 [format %.0f $core_area]
metric instances_netlist [llength [$block getInsts]]
set a0 [cell_area]
metric cell_area_after_taps_um2 [format %.0f $a0]
metric util_after_taps [format %.3f [expr {$a0 / $core_area}]]

# ---- placement ----
set dens [expr {min(0.97, $a0 / $core_area + $::env(DENSITY_ADD))}]
metric gpl_density [format %.3f $dens]
if {[catch {global_placement -density $dens} err]} {
    metric result "FAIL global_placement: $err"
    close $mf; exit 1
}
estimate_parasitics -placement
repair_tie_fanout -separation 5 sky130_fd_sc_hd__conb_1/HI
repair_tie_fanout -separation 5 sky130_fd_sc_hd__conb_1/LO
repair_design
if {[catch {detailed_placement} err]} {
    metric result "FAIL detailed_placement: $err"
    close $mf; exit 1
}
metric util_after_repair_design [format %.3f [expr {[cell_area] / $core_area}]]

# ---- clock tree ----
clock_tree_synthesis -root_buf sky130_fd_sc_hd__clkbuf_16 \
    -buf_list {sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8}
set_propagated_clock [all_clocks]
estimate_parasitics -placement
repair_timing -setup
repair_timing -hold -hold_margin 0.1
if {[catch {detailed_placement} err]} {
    metric result "FAIL detailed_placement after CTS: $err"
    close $mf; exit 1
}
check_placement
metric instances_placed [llength [$block getInsts]]
metric util_after_cts [format %.3f [expr {[cell_area] / $core_area}]]

# ---- global route ----
source $plat/fastroute.tcl
if {[catch {global_route -guide_file $out/route.guide -congestion_iterations 50 \
                -congestion_report_file $out/congestion.rpt} err]} {
    metric result "FAIL global_route: $err"
    close $mf; exit 1
}
estimate_parasitics -global_routing
metric grt "ok"

# ---- detailed route ----
set_thread_count 4
if {[catch {detailed_route -output_drc $out/drc.rpt -bottom_routing_layer met1 \
                -top_routing_layer met5 -verbose 1} err]} {
    metric result "FAIL detailed_route: $err"
    close $mf; exit 1
}
filler_placement {sky130_fd_sc_hd__fill_8 sky130_fd_sc_hd__fill_4 \
                  sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_1}
check_placement

# ---- save first, report after (report.tcl reads final.odb) ----
set drc 0
if {[file exists $out/drc.rpt]} {
    set fh [open $out/drc.rpt]; set txt [read $fh]; close $fh
    set drc [regexp -all {violation type:} $txt]
}
metric drc_violations $drc
metric util_final [format %.3f [expr {[cell_area] / $core_area}]]
write_db $out/final.odb
write_def $out/final.def
write_verilog $out/final.v
write_sdc $out/final.sdc
report_design_area
metric result "ok"
close $mf
exit 0
