`include "cnn_params.vh"
// Tap k is delayed by (k+1) registers so the pixel for tap k reaches PE k in the same
// cycle as the partial sum from PE k-1. Data path only: no reset, no enable.
module pixel_skew(
    input  wire                        clk,
    input  wire [(`K_SIZE*`ACT_W)-1:0] window_flat,
    output wire [(`K_SIZE*`ACT_W)-1:0] skew_flat
);
    genvar k;
    generate
        for (k = 0; k < `K_SIZE; k = k + 1) begin : SKEW
            reg [(k+1)*`ACT_W-1:0] sr;
            wire [`ACT_W-1:0] tap_in = window_flat[(k+1)*`ACT_W-1 -: `ACT_W];
            if (k == 0) begin : D0
                always @(posedge clk) sr <= tap_in;
            end else begin : DN
                always @(posedge clk) sr <= {sr[k*`ACT_W-1:0], tap_in};
            end
            assign skew_flat[(k+1)*`ACT_W-1 -: `ACT_W] = sr[(k+1)*`ACT_W-1 -: `ACT_W];
        end
    endgenerate
endmodule
