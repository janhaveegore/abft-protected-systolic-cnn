// Folder that contains img.hex, ker.hex, fm.hex, raw.hex, cs.hex.
// iverilog scripts run from the project root, so the relative default works there.
// For Vivado/xsim scripts/vivado_sim.tcl overwrites this file with an absolute path.
// Use forward slashes even on Windows.
`ifndef VEC_DIR
  //`define VEC_DIR "vectors"
  `define VEC_DIR "C:/Users/Janhavee/Downloads/cnn_abft_systolic_project/vectors"
`endif
