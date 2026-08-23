# CPLD supervisor - simulation
#
#   make            build + run the self-checking testbench
#   make wave       run, then open the VCD in GTKWave (or surfer)
#   make lint       Verilator lint pass (if installed)
#   make clean
#
# Exit status is the verdict: 0 = all checks passed, non-zero = failure.
# Suitable for CI as-is.

IVERILOG ?= iverilog
VVP      ?= vvp
VIEWER   ?= gtkwave

RTL  := ../rtl/supervisor.v
TB   := ../tb/supervisor_tb.sv
OUT  := supervisor_tb
VCD  := supervisor.vcd

.PHONY: all sim wave lint clean

all: sim

$(OUT): $(RTL) $(TB)
	$(IVERILOG) -g2012 -Wall -o $(OUT) $(RTL) $(TB)

sim: $(OUT)
	@mkdir -p .
	./$(OUT)

wave: sim
	$(VIEWER) $(VCD) &

lint:
	@command -v verilator >/dev/null 2>&1 \
	  && verilator --lint-only -Wall $(RTL) --top-module supervisor \
	  || echo "verilator not installed - skipping lint"

clean:
	rm -f $(OUT) $(VCD)
