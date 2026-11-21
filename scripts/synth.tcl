# Vivado out-of-context synthesis + implementation for ONE top.
# Run from the project root (one run per design):
#   vivado -mode batch -source scripts/synth.tcl -tclargs cnn_top      > results/viv_baseline.log
#   vivado -mode batch -source scripts/synth.tcl -tclargs cnn_top_sys  > results/viv_systolic.log
# Edit PART / PERIOD_NS below. Fault injection is NOT defined here (hooks are compiled out).
set PART      xc7s50csga324-1   ;# Spartan-7: change to YOUR part (Arty S7-25: xc7s25csga324-1, Cmod S7: xc7s25csga225-1)
set PERIOD_NS 10.0               ;# target clock; tighten it until WNS goes negative to find the real limit
set FLATTEN   rebuilt            ;# use "none" if you want a per-module (hierarchical) utilization breakdown

set top [lindex $argv 0]
if {$top ne "cnn_top" && $top ne "cnn_top_sys"} { puts "usage: -tclargs cnn_top|cnn_top_sys"; exit 1 }
set root [file normalize [pwd]]
set out  $root/results/vivado_$top
file mkdir $out

set shared [list window_controller address_generator pixel_memory sliding_window kernel_memory_we relu feature_map_memory]
set files {}
foreach m $shared { lappend files $root/rtl/$m.v }
if {$top eq "cnn_top"} {
    foreach m {cnn_top controller mac_unit mac_array adder_tree_9} { lappend files $root/rtl/baseline/$m.v }
} else {
    foreach m {cnn_top_sys pe systolic_chain pixel_skew abft_expected abft_checker controller_sys} { lappend files $root/rtl/systolic/$m.v }
}
read_verilog $files

synth_design -top $top -part $PART -mode out_of_context -flatten_hierarchy $FLATTEN -include_dirs $root/rtl
create_clock -period $PERIOD_NS -name clk [get_ports clk]
report_utilization              -file $out/util_synth.rpt
report_utilization -hierarchical -file $out/util_synth_hier.rpt
report_timing_summary           -file $out/timing_synth.rpt

opt_design
place_design
route_design
report_utilization              -file $out/util_impl.rpt
report_utilization -hierarchical -file $out/util_impl_hier.rpt
report_timing_summary           -file $out/timing_impl.rpt
report_power                    -file $out/power_impl.rpt

# Fmax = 1 / (T - WNS)   (valid only if the clock constraint is the limiting one)
set wns  [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set fmax [expr {1000.0 / ($PERIOD_NS - $wns)}]
set fh [open $out/summary.txt w]
puts $fh "top=$top part=$PART period_ns=$PERIOD_NS flatten=$FLATTEN"
puts $fh "post-route WNS(ns)=$wns  Fmax(MHz)=$fmax"
close $fh
puts "post-route WNS(ns)=$wns  Fmax(MHz)=$fmax"
