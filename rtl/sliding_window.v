`include "cnn_params.vh"
module sliding_window(input wire [(`K_SIZE*`ACT_W)-1:0] pixels_flat, output wire [(`K_SIZE*`ACT_W)-1:0] window_flat);
assign window_flat = pixels_flat;
endmodule
