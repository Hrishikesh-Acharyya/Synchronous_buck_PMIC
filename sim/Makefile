# Simulation and lint for the CPLD supervisor.
#
#   make        build and run the self-checking testbench
#   make wave   run, then open the waveform
#   make lint   Verilator lint pass
#   make clean  remove build outputs
#
# The testbench calls $fatal on a failed check, so a non-zero exit status
# indicates failure. Suitable for use as a CI step without log parsing.

IVERILOG ?= iverilog
VVP      ?= vvp
VIEWER   ?= gtkwave

RTL  := ../rtl/supervisor.sv
TB   := ../tb/supervisor_tb.sv
OUT  := supervisor_tb.vvp
VCD  := supervisor.vcd

.PHONY: all sim wave lint clean

all: sim

$(OUT): $(RTL) $(TB)
	$(IVERILOG) -g2012 -Wall -o $(OUT) $(RTL) $(TB)

sim: $(OUT)
	$(VVP) $(OUT)

wave: sim
	$(VIEWER) $(VCD) &

# Uses if/else rather than `command -v verilator && verilator ... || echo`:
# in the latter form a lint failure falls through to the fallback branch and
# make still exits 0, masking the error.
lint:
	@if command -v verilator >/dev/null 2>&1; then \
	  verilator --lint-only -Wall $(RTL) --top-module supervisor; \
	else \
	  echo "verilator not installed - skipping lint"; \
	fi

clean:
	rm -f $(OUT) $(VCD)
