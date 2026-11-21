`include "cnn_params.vh"
module relu(input wire signed [`ACC_W-1:0] in, output wire [`OUT_DATA_W-1:0] out);
assign out = (in < 0) ? {`OUT_DATA_W{1'b0}} : in[`OUT_DATA_W-1:0];
endmodule
