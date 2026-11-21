`include "cnn_params.vh"
module cnn_top(
    input  wire clk, input wire reset,
    input  wire img_we, input wire [`IMG_ADDR_W-1:0] img_waddr, input wire [`ACT_W-1:0] img_din,
    input  wire ker_we, input wire [`KER_ADDR_W-1:0] ker_waddr, input wire signed [`WEIGHT_W-1:0] ker_din,
    input  wire start, output wire done,
    input  wire [`OUT_ADDR_W-1:0] fm_raddr, output wire [`OUT_DATA_W-1:0] fm_dout
);
    wire [`OUT_ROW_BITS-1:0] row; wire [`OUT_COL_BITS-1:0] col; wire window_done;
    wire [(`K_SIZE*`IMG_ADDR_W)-1:0] addr_flat;
    wire [(`K_SIZE*`ACT_W)-1:0] pixels_flat, window_flat;
    wire [(`K_SIZE*`WEIGHT_W)-1:0] weights_flat;
    wire [(`K_SIZE*`PROD_W)-1:0] products_flat;
    wire signed [`ACC_W-1:0] acc_sum; wire [`OUT_DATA_W-1:0] relu_out;
    wire window_start, fm_we; wire [`OUT_ADDR_W-1:0] fm_waddr, fm_addr_mux;
    reg [`K_SIZE-1:0] tap_we;
    always @(*) begin : KERNEL_SEL
        integer k;
        for (k = 0; k < `K_SIZE; k = k + 1)
            tap_we[k] = ker_we && (ker_waddr == k[`KER_ADDR_W-1:0]);
    end
    assign fm_addr_mux = fm_we ? fm_waddr : fm_raddr;
    window_controller u_wc (.clk(clk),.reset(reset),.start(window_start),.row(row),.col(col),.window_done(window_done));
    address_generator u_ag (.row(row),.col(col),.addr_flat(addr_flat));
    pixel_memory u_pm (.clk(clk),.we(img_we),.write_addr(img_waddr),.data_in(img_din),.read_addr_flat(addr_flat),.pixels_flat(pixels_flat));
    sliding_window u_sw (.pixels_flat(pixels_flat),.window_flat(window_flat));
    genvar k;
    generate for (k = 0; k < `K_SIZE; k = k + 1) begin : KERNEL_TAPS
        kernel_memory_we u_km (.clk(clk),.we(tap_we[k]),.data_in(ker_din),.data_out(weights_flat[(k+1)*`WEIGHT_W-1 -: `WEIGHT_W]));
    end endgenerate
    mac_array u_ma (.pixels_flat(window_flat),.weights_flat(weights_flat),.products_flat(products_flat));
    adder_tree_9 u_at (.p_flat(products_flat),.sum(acc_sum));
    relu u_relu (.in(acc_sum),.out(relu_out));
    controller u_ctrl (.clk(clk),.reset(reset),.start(start),.window_done(window_done),.window_start(window_start),.fm_we(fm_we),.fm_addr(fm_waddr),.done(done));
    feature_map_memory u_fm (.clk(clk),.we(fm_we),.addr(fm_addr_mux),.data_in(relu_out),.data_out(fm_dout));
endmodule
