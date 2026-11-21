`include "cnn_params.vh"
// Run controller for the systolic design. Re-startable from DONE (no reset needed).
//  - start_accept : combinational pulse; loads PE weights and clears ABFT/counters
//  - window_start : held until window_done is seen; the existing window_controller clears
//                   itself on that same edge, so the next run starts clean.
//  - done         : set on the same edge the ABFT comparison is registered.
module controller_sys(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire window_done,
    input  wire chk_fire,
    output wire start_accept,
    output reg  window_start,
    output reg  done
);
    localparam IDLE = 2'd0, RUN = 2'd1, DONE = 2'd2;
    reg [1:0] state;

    assign start_accept = start & (state != RUN);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE; window_start <= 0; done <= 0;
        end else begin
            case (state)
                IDLE, DONE: if (start) begin
                    window_start <= 1'b1; done <= 1'b0; state <= RUN;
                end
                RUN: begin
                    if (window_done) window_start <= 1'b0;
                    if (chk_fire) begin done <= 1'b1; state <= DONE; end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
