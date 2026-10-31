#
# Filename:         image.tcl
#
# File Description: Saves a picture of a routed run, cropped to the die. Needs
#                   the OpenROAD GUI; run_pnr.sh runs it with
#                   QT_QPA_PLATFORM=offscreen, so no display is required.
#
# Global variables: Environment - RUN (run directory).

set run $::env(RUN)
read_db $run/final.odb
set block [ord::get_db_block]
set die [$block getDieArea]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set x1 [expr {double([$die xMax]) / $dbu}]
set y1 [expr {double([$die yMax]) / $dbu}]
if {[catch {save_image -area [list -2 -2 [expr {$x1 + 2}] [expr {$y1 + 2}]] -width 1400 $run/layout.png} err]} { puts "SAVE_IMAGE_ERROR $err" }
exit
