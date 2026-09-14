/*

# Filename:         pmic_types_pkg.sv

# File Description: Shared type definitions for the synchronous buck PMIC
#                   supervisor. Imported by both the RTL and the testbench so
#                   that state encodings and timing constants have exactly one
#                   definition. Re-encoding a state here updates the design and
#                   every check against it at the same time.

# Global variables: None (package-scoped types and parameters only)

*/

package pmic_types_pkg;

    /*
    Purpose:
    ---
    Supervisor FSM states.

      S_OFF    : converter disabled; all faults force entry here
      S_SS     : soft start active; output enabled, ramp in progress
      S_RUN    : normal regulation
      S_HICCUP : post-fault off-time; output disabled while the power stage
                 cools before the next retry attempt

    Encoding is binary. At 4 states on a MAX 10 this costs 2 flops against
    one-hot's 4, and the next-state logic is small enough that binary does not
    hurt timing.
    */
    typedef enum logic [1:0] {
        S_OFF    = 2'b00,
        S_SS     = 2'b01,
        S_RUN    = 2'b10,
        S_HICCUP = 2'b11
    } state_t;

    // HICCUP_OFF_CYCLES: Minimum clock cycles the FSM must remain in S_HICCUP
    //                    before retrying. Sets the converter's retry period,
    //                    which must be long enough for the power stage to cool
    //                    under a sustained short. Sized for the supervisor
    //                    clock; verify against the thermal budget before use.
    parameter int HICCUP_OFF_CYCLES = 50_000;

    // MAX_STRIKES: Number of consecutive failed retry attempts allowed before
    //              the supervisor latches off permanently and requires a power
    //              cycle or an explicit reset to recover.
    parameter int MAX_STRIKES = 3;

endpackage