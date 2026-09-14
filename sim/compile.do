vlib work
vmap work work

vlog -sv -work work ../rtl/pkg/pmic_types_pkg.sv
vlog -sv -work work ../rtl/supervisor.sv
vlog -sv -work work ../tb/supervisor_tb.sv

vsim -voptargs=+acc work.supervisor_tb
run -all