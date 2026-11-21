`include "cnn_params.vh"
// 9-PE linear weight-stationary chain. PE k holds w[k]. Partial sums flow PE0 -> PE8.
// x_flat tap k must arrive k+1 cycles after tap 0's window (pixel_skew does this).
module systolic_chain(
    input  wire                              clk,
    input  wire                              load_w,
    input  wire [(`K_SIZE*`WEIGHT_W)-1:0]    weights_flat,
    input  wire [(`K_SIZE*`ACT_W)-1:0]       x_flat,
    input  wire [(`K_SIZE*`PROD_W)-1:0]      prod_mask,
    input  wire [(`K_SIZE*`ACC_W)-1:0]       psum_mask,
    input  wire [(`K_SIZE*`WEIGHT_W)-1:0]    w_mask,
    input  wire [(`K_SIZE*`ACT_W)-1:0]       x_mask,
    output wire signed [`ACC_W-1:0]          p_out
);
    wire signed [`ACC_W-1:0] ps [0:`K_SIZE];
    assign ps[0] = {`ACC_W{1'b0}};

    genvar k;
    generate
        for (k = 0; k < `K_SIZE; k = k + 1) begin : PE_CHAIN
            pe u_pe (
                .clk       (clk),
                .load_w    (load_w),
                .w_in      (weights_flat[(k+1)*`WEIGHT_W-1 -: `WEIGHT_W]),
                .x_in      (x_flat[(k+1)*`ACT_W-1 -: `ACT_W]),
                .psum_in   (ps[k]),
                .psum_out  (ps[k+1]),
                .prod_mask (prod_mask[(k+1)*`PROD_W-1 -: `PROD_W]),
                .psum_mask (psum_mask[(k+1)*`ACC_W-1 -: `ACC_W]),
                .w_mask    (w_mask[(k+1)*`WEIGHT_W-1 -: `WEIGHT_W]),
                .x_mask    (x_mask[(k+1)*`ACT_W-1 -: `ACT_W])
            );
        end
    endgenerate

    assign p_out = ps[`K_SIZE];
endmodule
