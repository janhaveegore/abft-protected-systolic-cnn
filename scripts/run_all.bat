@echo off
REM Windows version. Needs iverilog + vvp + python on PATH. Run from anywhere:  scripts\run_all.bat
cd /d "%~dp0\.."
if not exist build mkdir build
if not exist results mkdir results
python model\gen_vectors.py || goto :err

set SHARED=rtl\window_controller.v rtl\address_generator.v rtl\pixel_memory.v rtl\sliding_window.v rtl\kernel_memory_we.v rtl\relu.v rtl\feature_map_memory.v
set SYS=rtl\systolic\cnn_top_sys.v rtl\systolic\pe.v rtl\systolic\systolic_chain.v rtl\systolic\pixel_skew.v rtl\systolic\abft_expected.v rtl\systolic\abft_checker.v rtl\systolic\controller_sys.v

echo == 1/3 baseline
iverilog -g2005 -Irtl -Itb -s tb_baseline_vec -o build\baseline.vvp %SHARED% rtl\baseline\cnn_top.v rtl\baseline\controller.v rtl\baseline\mac_unit.v rtl\baseline\mac_array.v rtl\baseline\adder_tree_9.v tb\tb_baseline_vec.v || goto :err
vvp build\baseline.vvp > results\sim_baseline.log & type results\sim_baseline.log

echo == 2/3 systolic + ABFT fault-free
iverilog -g2005 -Irtl -Itb -s tb_sys_func -o build\sys_func.vvp %SHARED% %SYS% tb\tb_sys_func.v || goto :err
vvp build\sys_func.vvp > results\sim_systolic_func.log & type results\sim_systolic_func.log

echo == 3/3 fault campaign
iverilog -g2005 -Irtl -Itb -DFAULT_INJ -s tb_sys_fi -o build\sys_fi.vvp %SHARED% %SYS% rtl\systolic\fault_unit.v tb\tb_sys_fi.v || goto :err
vvp build\sys_fi.vvp > results\sim_fault_campaign.log & type results\sim_fault_campaign.log
move /Y fi_misses.csv results\ >nul 2>&1
goto :eof
:err
echo FAILED
exit /b 1
