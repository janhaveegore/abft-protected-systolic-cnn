`include "cnn_params.vh"
module mac_array(input wire [(`K_SIZE*`ACT_W)-1:0] pixels_flat, input wire [(`K_SIZE*`WEIGHT_W)-1:0] weights_flat, output wire [(`K_SIZE*`PROD_W)-1:0] products_flat);
genvar i;
generate for(i=0;i<`K_SIZE;i=i+1) begin : MAC_ARRAY
    mac_unit mac_inst(.pixel(pixels_flat[(i+1)*`ACT_W-1 -: `ACT_W]),.weight(weights_flat[(i+1)*`WEIGHT_W-1 -: `WEIGHT_W]),.product(products_flat[(i+1)*`PROD_W-1 -: `PROD_W]));
end endgenerate
endmodule
