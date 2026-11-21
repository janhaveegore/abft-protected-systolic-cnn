`include "cnn_params.vh"
// SIMULATION ONLY (instantiated only when FAULT_INJ is defined).
// The testbench sets en/site/pe/win/bit_i by hierarchical reference.
// fcyc = clock edges since the start edge (E1): fcyc == m during the interval (E_m, E_m+1).
// Schedule (window o, PE/tap k):
//   PROD/PSUM/PIXIN : PE k processes window o in the interval with fcyc = o+k+2
//   WINCM           : window o is on window_flat when fcyc = o+1
//   POST/CHK        : raw output of window o is valid when fcyc = o+11
//   EXP             : expected-MAC accumulate step k (held in 'win') when fcyc = k+12
module fault_unit(
    input  wire [7:0] fcyc,
    output wire [`K_SIZE*`PROD_W-1:0]   prod_mask,
    output wire [`K_SIZE*`ACC_W-1:0]    psum_mask,
    output wire [`K_SIZE*`WEIGHT_W-1:0] w_mask,
    output wire [`K_SIZE*`ACT_W-1:0]    x_mask,
    output wire [`K_SIZE*`ACT_W-1:0]    win_mask,
    output wire [`OUT_DATA_W-1:0]       post_mask,
    output wire [`CS_W-1:0]             chk_mask,
    output wire [`CS_W-1:0]             exp_mask
);
    localparam S_PROD=0, S_PSUM=1, S_WGT=2, S_PIXIN=3, S_WINCM=4, S_POST=5, S_CHK=6, S_EXP=7;

    reg       en;
    reg [3:0] site, pe, win;
    reg [4:0] bit_i;
    initial begin en = 0; site = 0; pe = 0; win = 0; bit_i = 0; end

    wire [7:0] w8 = {4'b0, win};
    wire [7:0] p8 = {4'b0, pe};
    wire hit_pe  = en && (fcyc == w8 + p8 + 8'd2);
    wire hit_win = en && (fcyc == w8 + 8'd1);
    wire hit_out = en && (fcyc == w8 + 8'd11);
    wire hit_exp = en && (fcyc == w8 + 8'd12);

    genvar k;
    generate
        for (k = 0; k < `K_SIZE; k = k + 1) begin : G
            assign prod_mask[(k+1)*`PROD_W-1 -: `PROD_W]     = (hit_pe  && site==S_PROD  && pe==k) ? (16'd1 << bit_i) : 16'd0;
            assign psum_mask[(k+1)*`ACC_W-1 -: `ACC_W]       = (hit_pe  && site==S_PSUM  && pe==k) ? (20'd1 << bit_i) : 20'd0;
            assign w_mask   [(k+1)*`WEIGHT_W-1 -: `WEIGHT_W] = (en      && site==S_WGT   && pe==k) ? (8'd1  << bit_i) : 8'd0;
            assign x_mask   [(k+1)*`ACT_W-1 -: `ACT_W]       = (hit_pe  && site==S_PIXIN && pe==k) ? (8'd1  << bit_i) : 8'd0;
            assign win_mask [(k+1)*`ACT_W-1 -: `ACT_W]       = (hit_win && site==S_WINCM && pe==k) ? (8'd1  << bit_i) : 8'd0;
        end
    endgenerate
    assign post_mask = (hit_out && site==S_POST) ? (8'd1  << bit_i) : 8'd0;
    assign chk_mask  = (hit_out && site==S_CHK ) ? (23'd1 << bit_i) : 23'd0;
    assign exp_mask  = (hit_exp && site==S_EXP ) ? (23'd1 << bit_i) : 23'd0;
endmodule
