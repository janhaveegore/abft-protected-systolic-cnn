`ifndef CNN_PARAMS_VH
`define CNN_PARAMS_VH
`define IMG_H        5
`define IMG_W        5
`define KER_H        3
`define KER_W        3
`define K_SIZE       9
`define STRIDE       1
`define PADDING      0
`define OUT_H        3
`define OUT_FM_W     3
`define OUT_SIZE     9
`define IMG_SIZE     25
`define ACT_W        8
`define WEIGHT_W     8
`define PROD_W       16
`define ACC_W        20
`define OUT_DATA_W   8
`define IMG_ADDR_W   5
`define KER_ADDR_W   4
`define OUT_ADDR_W   4
`define IMG_ROW_BITS 3
`define IMG_COL_BITS 3
`define OUT_ROW_BITS 2
`define OUT_COL_BITS 2
`define TREE_L0_W    17
`define TREE_L1_W    18
`define TREE_L2_W    19
`define TREE_L3_W    20

// ---- added for the ABFT / systolic design (baseline ignores these) ----
`define CS_W         23   // exact checksum width: |sum of 9 outputs| <= 2,643,840 < 2^22
`define S_W         12   // per-tap pixel sum over 9 windows: 9*255 = 2295 < 2^12
`define SA_LAT      10   // issue_valid -> p8 valid, in clock edges (skew k+1, chain k+1, 9 taps)
`endif
