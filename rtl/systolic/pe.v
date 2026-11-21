`include "cnn_params.vh"
// Weight-stationary processing element.
//   w          : local weight register, loaded once per run (load_w)
//   psum_out   : registered  psum_in + (unsigned pixel * signed weight)
// *_mask inputs are XOR bit-flip hooks for simulation; they are tied to 0 in
// non-fault builds, so synthesis removes them.
module pe(
    input  wire                        clk,
    input  wire                        load_w,
    input  wire signed [`WEIGHT_W-1:0] w_in,
    input  wire        [`ACT_W-1:0]    x_in,
    input  wire signed [`ACC_W-1:0]    psum_in,
    output reg  signed [`ACC_W-1:0]    psum_out,
    input  wire        [`PROD_W-1:0]   prod_mask,
    input  wire        [`ACC_W-1:0]    psum_mask,
    input  wire        [`WEIGHT_W-1:0] w_mask,
    input  wire        [`ACT_W-1:0]    x_mask
);
    reg signed [`WEIGHT_W-1:0] w;

    wire        [`ACT_W-1:0]  x_eff    = x_in ^ x_mask;
    // zero-extend the pixel to 9-bit signed, then signed*signed
    wire signed [`PROD_W-1:0] prod_raw = $signed({1'b0, x_eff}) * w;
    wire signed [`PROD_W-1:0] prod     = prod_raw ^ $signed(prod_mask);
    wire signed [`ACC_W-1:0]  sum      = psum_in + prod;          // prod sign-extends to 20 bits

    always @(posedge clk) begin
        if (load_w) w <= w_in ^ $signed(w_mask);
        psum_out <= sum ^ $signed(psum_mask);
    end
endmodule
