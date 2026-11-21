`include "cnn_params.vh"
module window_controller(
    input wire clk, input wire reset, input wire start,
    output reg [`OUT_ROW_BITS-1:0] row, output reg [`OUT_COL_BITS-1:0] col, output reg window_done);
always @(posedge clk or posedge reset) begin
    if(reset) begin row<=0; col<=0; window_done<=0; end
    else if(start && window_done) begin row<=0; col<=0; window_done<=0; end
    else if(start && !window_done) begin
        if((row==(`OUT_H-1)) && (col==(`OUT_FM_W-1))) window_done<=1;
        else if(col==(`OUT_FM_W-1)) begin col<=0; row<=row+1; end
        else col<=col+1;
    end
end
endmodule
