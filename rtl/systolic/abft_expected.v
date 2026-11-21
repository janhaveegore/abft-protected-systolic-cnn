`include "cnn_params.vh"
// Independent expected checksum:  C_exp = sum_k  w_k * ( sum_o pixel(o,k) )
// Phase 1 (while windows stream): S_k += pixel_k for each valid window.
// Phase 2: one pipelined 12x8 multiplier walks k = 0..8 and accumulates.
// Uses only the window pixels and the MASTER kernel registers - never the systolic outputs.
module abft_expected(
    input  wire                              clk,
    input  wire                              reset,
    input  wire                              clear,
    input  wire                              win_valid,
    input  wire [(`K_SIZE*`ACT_W)-1:0]       win_flat,
    input  wire [(`K_SIZE*`WEIGHT_W)-1:0]    weights_flat,
    input  wire [`CS_W-1:0]                  exp_mask,
    output reg  signed [`CS_W-1:0]           exp_cs,
    output reg                               exp_valid
);
    reg [`S_W-1:0] S [0:`K_SIZE-1];
    reg            win_q, run, v1, v2;
    reg [3:0]      sel, n;
    reg [`S_W-1:0] s_sel;
    reg signed [`WEIGHT_W-1:0] w_sel;
    reg signed [`S_W+`WEIGHT_W:0] p_reg;      // 21 bits

    wire last   = win_q & ~win_valid;         // falling edge of the window stream
    wire active = last | run;

    wire signed [`S_W+`WEIGHT_W:0] prod_s = $signed({1'b0, s_sel}) * w_sel;

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            win_q <= 0; run <= 0; v1 <= 0; v2 <= 0; sel <= 0; n <= 0;
            exp_cs <= 0; exp_valid <= 0;
        end else if (clear) begin
            for (i = 0; i < `K_SIZE; i = i + 1) S[i] <= 0;
            win_q <= 0; run <= 0; v1 <= 0; v2 <= 0; sel <= 0; n <= 0;
            exp_cs <= 0; exp_valid <= 0;
        end else begin
            win_q <= win_valid;
            if (win_valid)
                for (i = 0; i < `K_SIZE; i = i + 1)
                    S[i] <= S[i] + win_flat[i*`ACT_W +: `ACT_W];

            // stage 1: select S_k and w_k
            v1 <= active;
            if (active) begin
                s_sel <= S[sel];
                w_sel <= weights_flat[sel*`WEIGHT_W +: `WEIGHT_W];
                sel   <= sel + 1;
                run   <= (sel != `K_SIZE-1);
            end
            // stage 2: multiply
            v2    <= v1;
            p_reg <= prod_s;
            // stage 3: accumulate
            if (v2) begin
                exp_cs <= (exp_cs + p_reg) ^ $signed(exp_mask);
                n      <= n + 1;
                if (n == `K_SIZE-1) exp_valid <= 1'b1;
            end
        end
    end
endmodule
