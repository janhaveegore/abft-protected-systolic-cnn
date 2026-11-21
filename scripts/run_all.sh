#!/bin/sh
# Runs the whole simulation flow with Icarus Verilog. Usage:  sh scripts/run_all.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p build results

python3 model/gen_vectors.py

SHARED="rtl/window_controller.v rtl/address_generator.v rtl/pixel_memory.v rtl/sliding_window.v rtl/kernel_memory_we.v rtl/relu.v rtl/feature_map_memory.v"
SYS_NOFI="rtl/systolic/cnn_top_sys.v rtl/systolic/pe.v rtl/systolic/systolic_chain.v rtl/systolic/pixel_skew.v rtl/systolic/abft_expected.v rtl/systolic/abft_checker.v rtl/systolic/controller_sys.v"

echo "== 1/3 baseline MAC design"
iverilog -g2005 -Irtl -Itb -s tb_baseline_vec -o build/baseline.vvp $SHARED rtl/baseline/*.v tb/tb_baseline_vec.v
vvp build/baseline.vvp | tee results/sim_baseline.log | tail -4

echo "== 2/3 systolic + ABFT, fault-free (fault hooks compiled out)"
iverilog -g2005 -Irtl -Itb -s tb_sys_func -o build/sys_func.vvp $SHARED $SYS_NOFI tb/tb_sys_func.v
vvp build/sys_func.vvp | tee results/sim_systolic_func.log | tail -9

echo "== 3/3 fault-injection campaign (takes about a minute)"
iverilog -g2005 -Irtl -Itb -DFAULT_INJ -s tb_sys_fi -o build/sys_fi.vvp $SHARED rtl/systolic/*.v tb/tb_sys_fi.v
vvp build/sys_fi.vvp | tee results/sim_fault_campaign.log | tail -16
mv -f fi_misses.csv results/ 2>/dev/null || true
echo "Logs are in results/"
