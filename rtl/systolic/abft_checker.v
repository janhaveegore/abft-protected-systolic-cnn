`include "cnn_params.vh"
// Pre-ReLU, pre-truncation checker: C_computed = sum of the nine raw 20-bit outputs (23-bit exact).
module abft_checker(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        clear,
    input  wire                        sample_valid,
    input  wire signed [`ACC_W-1:0]    p_raw,
    input  wire signed [`CS_W-1:0]     exp_cs,
    input  wire                        exp_valid,
    input  wire        [`CS_W-1:0]     chk_mask,
    output wire                        fire,       // comparison is registered on this edge
    output reg                         err,
    output reg                         chk_done
);
    reg signed [`CS_W-1:0] sum;
    reg [3:0] cnt;
    reg       sum_ready;

    assign fire = sum_ready & exp_valid & ~chk_done;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sum <= 0; cnt <= 0; sum_ready <= 0; err <= 0; chk_done <= 0;
        end else if (clear) begin
            sum <= 0; cnt <= 0; sum_ready <= 0; err <= 0; chk_done <= 0;
        end else begin
            if (sample_valid) begin
                sum <= (sum + p_raw) ^ $signed(chk_mask);
                cnt <= cnt + 1;
                if (cnt == `OUT_SIZE-1) sum_ready <= 1'b1;
            end
            if (fire) begin
                err      <= (sum != exp_cs);
                chk_done <= 1'b1;
            end
        end
    end
endmodule
