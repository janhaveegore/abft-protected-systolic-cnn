`include "cnn_params.vh"
module mac_unit(input wire [`ACT_W-1:0] pixel, input wire signed [`WEIGHT_W-1:0] weight, output wire signed [`PROD_W-1:0] product);
assign product = $signed({1'b0, pixel}) * weight;
endmodule
