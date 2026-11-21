`include "cnn_params.vh"
module controller(
    input wire clk, input wire reset, input wire start, input wire window_done,
    output reg window_start, output reg fm_we, output reg [`OUT_ADDR_W-1:0] fm_addr, output reg done);
localparam IDLE=2'd0, RUN=2'd1, DONE=2'd2;
reg [1:0] state;
always @(posedge clk or posedge reset) begin
    if(reset) begin state<=IDLE; window_start<=0; fm_we<=0; fm_addr<=0; done<=0; end
    else case(state)
        IDLE: begin
            fm_we<=0; done<=0; fm_addr<=0; window_start<=0;
            if(start) begin window_start<=1; fm_we<=1; state<=RUN; end
        end
        RUN: begin
            window_start<=1; fm_we<=1;
            if(window_done) begin fm_we<=0; done<=1; state<=DONE; end
            else fm_addr<=fm_addr+1;
        end
        DONE: begin window_start<=0; fm_we<=0; done<=1; end
        default: state<=IDLE;
    endcase
end
endmodule
