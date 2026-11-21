# Builds a Vivado project in ./vivado_sim/<tb> and runs one testbench in xsim.
# Run from the project root:
#   vivado -mode batch -source scripts/vivado_sim.tcl -tclargs tb_baseline_vec
#   vivado -mode batch -source scripts/vivado_sim.tcl -tclargs tb_sys_func
#   vivado -mode batch -source scripts/vivado_sim.tcl -tclargs tb_sys_fi      ;# fault campaign, slowest
# (Replace "-mode batch" with "-mode gui" to watch waveforms.)  Edit PART for your board.
set PART xc7s50csga324-1
set tb [lindex $argv 0]
if {[lsearch {tb_baseline_vec tb_sys_func tb_sys_fi} $tb] < 0} { puts "usage: -tclargs tb_baseline_vec|tb_sys_func|tb_sys_fi"; exit 1 }
set root [file normalize [pwd]]

# testbenches find the .hex vectors through this one-line header
set fh [open $root/tb/vec_path.vh w]
puts $fh "`define VEC_DIR \"$root/vectors\""
close $fh

create_project -force sim_$tb $root/vivado_sim/$tb -part $PART
add_files [concat [glob $root/rtl/*.v] [glob $root/rtl/baseline/*.v] [glob $root/rtl/systolic/*.v]]
add_files [list $root/rtl/cnn_params.vh $root/tb/vec_path.vh]
set_property file_type {Verilog Header} [get_files *.vh]
set_property include_dirs [list $root/rtl $root/tb] [get_filesets sources_1]
add_files -fileset sim_1 $root/tb/$tb.v
set_property include_dirs [list $root/rtl $root/tb] [get_filesets sim_1]
set_property top $tb [get_filesets sim_1]
if {$tb eq "tb_sys_fi"} { set_property verilog_define {FAULT_INJ} [get_filesets sim_1] }
update_compile_order -fileset sim_1

launch_simulation
run all
close_sim
