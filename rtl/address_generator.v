`include "cnn_params.vh"
module address_generator(
    input wire [`OUT_ROW_BITS-1:0] row, input wire [`OUT_COL_BITS-1:0] col,
    output reg [(`K_SIZE*`IMG_ADDR_W)-1:0] addr_flat);
    reg [31:0] base;
    always @(*) begin
        base = (row * `IMG_W) + col;
        addr_flat[1*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base;
        addr_flat[2*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + 1;
        addr_flat[3*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + 2;
        addr_flat[4*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + `IMG_W;
        addr_flat[5*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + `IMG_W + 1;
        addr_flat[6*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + `IMG_W + 2;
        addr_flat[7*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + (2 * `IMG_W);
        addr_flat[8*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + (2 * `IMG_W) + 1;
        addr_flat[9*`IMG_ADDR_W-1 -: `IMG_ADDR_W] = base + (2 * `IMG_W) + 2;
    end
endmodule
