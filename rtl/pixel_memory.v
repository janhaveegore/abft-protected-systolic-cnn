`include "cnn_params.vh"
module pixel_memory(
    input clk, input we, input [`IMG_ADDR_W-1:0] write_addr, input [`ACT_W-1:0] data_in,
    input [(`K_SIZE*`IMG_ADDR_W)-1:0] read_addr_flat, output [(`K_SIZE*`ACT_W)-1:0] pixels_flat);
reg [`ACT_W-1:0] memory [0:`IMG_SIZE-1];
always @(posedge clk) if(we) memory[write_addr] <= data_in;
genvar i;
generate for(i=0;i<`K_SIZE;i=i+1) begin : READ_PORTS
    assign pixels_flat[(i+1)*`ACT_W-1 -: `ACT_W] = memory[ read_addr_flat[(i+1)*`IMG_ADDR_W-1 -: `IMG_ADDR_W] ];
end endgenerate
endmodule
