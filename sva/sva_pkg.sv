/*

# Filename:         sva_pkg.sv

# File Description: Shared tallies for all bound SVA checkers. Package variables
#                   are static and visible to every module in the compilation,
#                   so a checker bound at any hierarchy depth can report into
#                   the same counter that the testbench verdict block reads.

# Global variables: sva_failures - running count of assertion failures across
#                                  every bound checker in the current run

*/

package sva_pkg;

    int unsigned sva_failures = 0;

    // note_failure: called from an assertion's else clause. Uses $display, not
    //               $error, because Verilator's runtime error limit defaults to
    //               1 and would end the run on the first failure.
    function automatic void note_failure(string msg);
        sva_failures++;
        $display("[%0t] SVA FAIL: %s", $time, msg);
    endfunction

endpackage

