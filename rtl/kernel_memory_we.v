`include "cnn_params.vh"
module kernel_memory_we(input wire clk, input wire we, input wire signed [`WEIGHT_W-1:0] data_in, output reg signed [`WEIGHT_W-1:0] data_out);
always @(posedge clk) if (we) data_out <= data_in;
endmodule
