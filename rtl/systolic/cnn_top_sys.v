`include "cnn_params.vh"
// ABFT-protected, 9-PE weight-stationary systolic CNN accelerator.
// Same ports as cnn_top plus abft_err (valid when done=1).
module cnn_top_sys(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        img_we,
    input  wire [`IMG_ADDR_W-1:0]      img_waddr,
    input  wire [`ACT_W-1:0]           img_din,
    input  wire                        ker_we,
    input  wire [`KER_ADDR_W-1:0]      ker_waddr,
    input  wire signed [`WEIGHT_W-1:0] ker_din,
    input  wire                        start,
    output wire                        done,
    input  wire [`OUT_ADDR_W-1:0]      fm_raddr,
    output wire [`OUT_DATA_W-1:0]      fm_dout,
    output wire                        abft_err
);
    // ---------------- existing front end (reused unchanged) ----------------
    wire [`OUT_ROW_BITS-1:0]         row;
    wire [`OUT_COL_BITS-1:0]         col;
    wire                             window_done, window_start, start_accept, chk_fire;
    wire [(`K_SIZE*`IMG_ADDR_W)-1:0] addr_flat;
    wire [(`K_SIZE*`ACT_W)-1:0]      pixels_flat, window_flat;
    wire [(`K_SIZE*`WEIGHT_W)-1:0]   weights_flat;

    reg [`K_SIZE-1:0] tap_we;
    always @(*) begin : KERNEL_SEL
        integer k;
        for (k = 0; k < `K_SIZE; k = k + 1)
            tap_we[k] = ker_we && (ker_waddr == k[`KER_ADDR_W-1:0]);
    end

    window_controller u_wc (.clk(clk), .reset(reset), .start(window_start),
                            .row(row), .col(col), .window_done(window_done));
    address_generator u_ag (.row(row), .col(col), .addr_flat(addr_flat));
    pixel_memory      u_pm (.clk(clk), .we(img_we), .write_addr(img_waddr), .data_in(img_din),
                            .read_addr_flat(addr_flat), .pixels_flat(pixels_flat));
    sliding_window    u_sw (.pixels_flat(pixels_flat), .window_flat(window_flat));

    genvar g;
    generate
        for (g = 0; g < `K_SIZE; g = g + 1) begin : KERNEL_TAPS
            kernel_memory_we u_km (.clk(clk), .we(tap_we[g]), .data_in(ker_din),
                                   .data_out(weights_flat[(g+1)*`WEIGHT_W-1 -: `WEIGHT_W]));
        end
    endgenerate

    // ---------------- fault-injection masks (all zero unless FAULT_INJ) ----------------
    wire [`K_SIZE*`PROD_W-1:0]   prod_mask;
    wire [`K_SIZE*`ACC_W-1:0]    psum_mask;
    wire [`K_SIZE*`WEIGHT_W-1:0] w_mask;
    wire [`K_SIZE*`ACT_W-1:0]    x_mask, win_mask;
    wire [`OUT_DATA_W-1:0]       post_mask;
    wire [`CS_W-1:0]             chk_mask, exp_mask;
`ifdef FAULT_INJ
    reg [7:0] fcyc;
    always @(posedge clk or posedge reset) begin
        if (reset)                               fcyc <= 8'd0;
        else if (start_accept)                   fcyc <= 8'd1;
        else if (fcyc != 8'd0 && fcyc != 8'hFF)  fcyc <= fcyc + 8'd1;
    end
    wire [`K_SIZE*`PROD_W-1:0]   pm0, pm1;
    wire [`K_SIZE*`ACC_W-1:0]    sm0, sm1;
    wire [`K_SIZE*`WEIGHT_W-1:0] wm0, wm1;
    wire [`K_SIZE*`ACT_W-1:0]    xm0, xm1, nm0, nm1;
    wire [`OUT_DATA_W-1:0]       qm0, qm1;
    wire [`CS_W-1:0]             cm0, cm1, em0, em1;
    fault_unit u_fi0 (.fcyc(fcyc), .prod_mask(pm0), .psum_mask(sm0), .w_mask(wm0), .x_mask(xm0),
                      .win_mask(nm0), .post_mask(qm0), .chk_mask(cm0), .exp_mask(em0));
    fault_unit u_fi1 (.fcyc(fcyc), .prod_mask(pm1), .psum_mask(sm1), .w_mask(wm1), .x_mask(xm1),
                      .win_mask(nm1), .post_mask(qm1), .chk_mask(cm1), .exp_mask(em1));
    assign prod_mask = pm0 ^ pm1;   assign psum_mask = sm0 ^ sm1;
    assign w_mask    = wm0 ^ wm1;   assign x_mask    = xm0 ^ xm1;
    assign win_mask  = nm0 ^ nm1;   assign post_mask = qm0 ^ qm1;
    assign chk_mask  = cm0 ^ cm1;   assign exp_mask  = em0 ^ em1;
`else
    assign prod_mask = {(`K_SIZE*`PROD_W){1'b0}};
    assign psum_mask = {(`K_SIZE*`ACC_W){1'b0}};
    assign w_mask    = {(`K_SIZE*`WEIGHT_W){1'b0}};
    assign x_mask    = {(`K_SIZE*`ACT_W){1'b0}};
    assign win_mask  = {(`K_SIZE*`ACT_W){1'b0}};
    assign post_mask = {`OUT_DATA_W{1'b0}};
    assign chk_mask  = {`CS_W{1'b0}};
    assign exp_mask  = {`CS_W{1'b0}};
`endif

    // ---------------- tap point: the systolic path AND the ABFT path both see this ----------------
    wire [(`K_SIZE*`ACT_W)-1:0] win_tap = window_flat ^ win_mask;

    // valid tracking
    wire issue_valid = window_start & ~window_done;      // window o on win_tap, 9 cycles
    reg [`SA_LAT-1:0] vpipe;
    always @(posedge clk or posedge reset)
        if (reset) vpipe <= 0;
        else       vpipe <= {vpipe[`SA_LAT-2:0], issue_valid};
    wire out_valid = vpipe[`SA_LAT-1];                    // p8 holds a raw output

    // ---------------- systolic datapath ----------------
    wire [(`K_SIZE*`ACT_W)-1:0] skew_flat;
    wire signed [`ACC_W-1:0]    p8;
    pixel_skew u_skew (.clk(clk), .window_flat(win_tap), .skew_flat(skew_flat));
    systolic_chain u_sa (.clk(clk), .load_w(start_accept), .weights_flat(weights_flat),
                         .x_flat(skew_flat), .prod_mask(prod_mask), .psum_mask(psum_mask),
                         .w_mask(w_mask), .x_mask(x_mask), .p_out(p8));

    // ---------------- ReLU + feature-map write ----------------
    wire [`OUT_DATA_W-1:0] relu_out;
    relu u_relu (.in(p8), .out(relu_out));
    wire [`OUT_DATA_W-1:0] relu_out_f = relu_out ^ post_mask;

    reg [`OUT_ADDR_W-1:0] fm_waddr;
    always @(posedge clk or posedge reset)
        if (reset)             fm_waddr <= 0;
        else if (start_accept) fm_waddr <= 0;
        else if (out_valid)    fm_waddr <= fm_waddr + 1'b1;

    wire fm_we = out_valid;
    wire [`OUT_ADDR_W-1:0] fm_addr_mux = fm_we ? fm_waddr : fm_raddr;
    feature_map_memory u_fm (.clk(clk), .we(fm_we), .addr(fm_addr_mux),
                             .data_in(relu_out_f), .data_out(fm_dout));

    // ---------------- ABFT ----------------
    wire signed [`CS_W-1:0] exp_cs;
    wire exp_valid, chk_done;
    abft_expected u_exp (.clk(clk), .reset(reset), .clear(start_accept), .win_valid(issue_valid),
                         .win_flat(win_tap), .weights_flat(weights_flat), .exp_mask(exp_mask),
                         .exp_cs(exp_cs), .exp_valid(exp_valid));
    abft_checker u_chk (.clk(clk), .reset(reset), .clear(start_accept), .sample_valid(out_valid),
                        .p_raw(p8), .exp_cs(exp_cs), .exp_valid(exp_valid), .chk_mask(chk_mask),
                        .fire(chk_fire), .err(abft_err), .chk_done(chk_done));

    controller_sys u_ctrl (.clk(clk), .reset(reset), .start(start), .window_done(window_done),
                           .chk_fire(chk_fire), .start_accept(start_accept),
                           .window_start(window_start), .done(done));
endmodule
