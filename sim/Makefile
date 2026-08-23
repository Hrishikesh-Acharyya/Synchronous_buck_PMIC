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

# Note the if/else rather than `cmd && verilator ... || echo`: with the &&/||
# form, a real lint failure falls through to the echo and make still exits 0,
# which silently disarms this target in CI.
lint:
	@if command -v verilator >/dev/null 2>&1; then \
	  verilator --lint-only -Wall $(RTL) --top-module supervisor; \
	else \
	  echo "verilator not installed - skipping lint"; \
	fi

clean:
	rm -f $(OUT) $(VCD)
