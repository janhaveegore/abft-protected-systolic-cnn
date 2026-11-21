`include "cnn_params.vh"
module feature_map_memory(input clk, input we, input [`OUT_ADDR_W-1:0] addr, input [`OUT_DATA_W-1:0] data_in, output [`OUT_DATA_W-1:0] data_out);
reg [`OUT_DATA_W-1:0] memory [0:`OUT_SIZE-1];
always @(posedge clk) if(we) memory[addr] <= data_in;
assign data_out = memory[addr];
endmodule
