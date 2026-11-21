`include "cnn_params.vh"
`timescale 1ns/1ps
`include "vec_path.vh"
// Simulation-only fault-injection campaign. Compile with -DFAULT_INJ.
// For each selected vector: golden run, then every single bit-flip at 8 fault sites, then a
// double-fault (two compensating flips) experiment. Everything is classified against the golden run:
//   DET_VIS   : abft_err=1, 8-bit feature map differs         (detected, visible corruption)
//   DET_INV   : abft_err=1, raw output differs, fm identical  (detected, hidden by ReLU/truncation)
//   MISS      : abft_err=0, feature map differs                (SILENT DATA CORRUPTION)
//   MISS_BEN  : abft_err=0, raw differs, feature map identical (undetected, output unaffected)
//   NO_EFFECT : abft_err=0, nothing differs                    (fault was masked/benign)
//   FALSE_ALM : abft_err=1, nothing differs                    (alarm with no data error)
module tb_sys_fi;
    parameter NV   = 57;
    parameter NSEL = 4;
    reg clk, reset, img_we, ker_we, start;
    reg [`IMG_ADDR_W-1:0] img_waddr; reg [`ACT_W-1:0] img_din;
    reg [`KER_ADDR_W-1:0] ker_waddr; reg signed [`WEIGHT_W-1:0] ker_din;
    reg [`OUT_ADDR_W-1:0] fm_raddr;
    wire done, abft_err; wire [`OUT_DATA_W-1:0] fm_dout;

    cnn_top_sys dut(.clk(clk),.reset(reset),.img_we(img_we),.img_waddr(img_waddr),.img_din(img_din),
        .ker_we(ker_we),.ker_waddr(ker_waddr),.ker_din(ker_din),.start(start),.done(done),
        .fm_raddr(fm_raddr),.fm_dout(fm_dout),.abft_err(abft_err));

    initial clk = 0;
    always #5 clk = ~clk;

    reg [7:0] img_v [0:NV*25-1];
    reg [7:0] ker_v [0:NV*9-1];
    integer sel_list [0:NSEL-1];

    reg [19:0] raw_cap [0:8];
    integer rcnt;
    always @(posedge clk) begin
        if (dut.start_accept) rcnt = 0;
        if (dut.out_valid) begin raw_cap[rcnt] = dut.p8; rcnt = rcnt + 1; end
    end

    reg [19:0] gold_raw [0:8];
    reg [7:0]  gold_fm  [0:8];
    reg [7:0]  fm_cap   [0:8];
    reg        err_cap;

    // stats[site*8 + class]
    integer stats [0:63];
    localparam C_N=0, C_DETV=1, C_DETI=2, C_MISS=3, C_MISSB=4, C_NOEFF=5, C_FA=6;
    integer i, j, v, vi, site, pe, win, bt, np, nw, nb;
    integer raw_diff, fm_diff, cls;
    integer dbl_n, dbl_miss_raw, dbl_miss_fm, dbl_det, a, b;
    integer fd;

    task clear_faults;
    begin
        dut.u_fi0.en = 0; dut.u_fi1.en = 0;
    end
    endtask

    task run_dut;
    integer guard;
    begin
        @(negedge clk);                       // re-align: the read-back loop uses #1 delays
        start = 1; @(negedge clk); start = 0;
        guard = 0;
        while (!done && guard < 200) begin @(negedge clk); guard = guard + 1; end
        if (guard >= 200) $display("ERROR: run did not finish");
        @(negedge clk);
        for (j = 0; j < 9; j = j + 1) begin fm_raddr = j; #1; fm_cap[j] = fm_dout; end
        err_cap = abft_err;
    end
    endtask

    task compare_gold;
    begin
        raw_diff = 0; fm_diff = 0;
        for (j = 0; j < 9; j = j + 1) begin
            if (raw_cap[j] !== gold_raw[j]) raw_diff = 1;
            if (fm_cap[j]  !== gold_fm[j])  fm_diff  = 1;
        end
    end
    endtask

    task classify;           // uses raw_diff, fm_diff, err_cap
    begin
        if (err_cap) begin
            if (!raw_diff && !fm_diff) cls = C_FA;
            else if (fm_diff)          cls = C_DETV;
            else                       cls = C_DETI;
        end else begin
            if (fm_diff)               cls = C_MISS;
            else if (raw_diff)         cls = C_MISSB;
            else                       cls = C_NOEFF;
        end
    end
    endtask

    task single_fault(input integer s, input integer p, input integer w, input integer bb);
    begin
        dut.u_fi0.en = 1; dut.u_fi0.site = s; dut.u_fi0.pe = p; dut.u_fi0.win = w; dut.u_fi0.bit_i = bb;
        run_dut; compare_gold; classify;
        stats[s*8 + C_N] = stats[s*8 + C_N] + 1;
        stats[s*8 + cls] = stats[s*8 + cls] + 1;
        if (cls == C_MISS || cls == C_FA)
            $fdisplay(fd, "vec,%0d,site,%0d,pe,%0d,win,%0d,bit,%0d,class,%0s", sel_list[vi], s, p, w, bb, (cls==C_MISS) ? "MISS" : "FALSE_ALARM");
        dut.u_fi0.en = 0;
    end
    endtask

    task sweep(input integer s, input integer npe, input integer nwin, input integer nbit);
    integer p, w, bb;
    begin
        for (p = 0; p < npe; p = p + 1)
            for (w = 0; w < nwin; w = w + 1)
                for (bb = 0; bb < nbit; bb = bb + 1)
                    single_fault(s, p, w, bb);
    end
    endtask

    task show_row(input integer s, input [8*10-1:0] name);
    begin
        $display("%-10s | %6d | %7d | %7d | %5d | %8d | %8d | %9d", name, stats[s*8+C_N], stats[s*8+C_DETV],
                 stats[s*8+C_DETI], stats[s*8+C_MISS], stats[s*8+C_MISSB], stats[s*8+C_NOEFF], stats[s*8+C_FA]);
    end
    endtask

    initial begin
        $readmemh({`VEC_DIR, "/img.hex"}, img_v); $readmemh({`VEC_DIR, "/ker.hex"}, ker_v);
        sel_list[0] = 0; sel_list[1] = 1; sel_list[2] = 5; sel_list[3] = 8;
        for (i = 0; i < 64; i = i + 1) stats[i] = 0;
        dbl_n = 0; dbl_miss_raw = 0; dbl_miss_fm = 0; dbl_det = 0; rcnt = 0;
        fd = $fopen("fi_misses.csv", "w");
        reset = 1; img_we = 0; ker_we = 0; start = 0; img_waddr = 0; img_din = 0; ker_waddr = 0; ker_din = 0; fm_raddr = 0;
        repeat (3) @(negedge clk);

        for (vi = 0; vi < NSEL; vi = vi + 1) begin
            v = sel_list[vi];
            reset = 1; repeat (2) @(negedge clk); reset = 0; @(negedge clk);
            img_we = 1;
            for (i = 0; i < 25; i = i + 1) begin img_waddr = i; img_din = img_v[v*25+i]; @(negedge clk); end
            img_we = 0; ker_we = 1;
            for (i = 0; i < 9; i = i + 1) begin ker_waddr = i; ker_din = ker_v[v*9+i]; @(negedge clk); end
            ker_we = 0; @(negedge clk);

            clear_faults;
            run_dut;                                   // golden run
            for (j = 0; j < 9; j = j + 1) begin gold_raw[j] = raw_cap[j]; gold_fm[j] = fm_cap[j]; end
            if (err_cap) $display("WARNING: golden run raised abft_err (vector %0d)", v);

            sweep(0, 9, 9, 16);   // PROD  : product register bit flip
            sweep(1, 9, 9, 20);   // PSUM  : partial-sum register bit flip
            sweep(2, 9, 1, 8);    // WGT   : PE-local weight register bit flip (persists for the run)
            sweep(3, 9, 9, 8);    // PIXIN : pixel at PE input (after tap point)
            sweep(4, 9, 9, 8);    // WINCM : window pixel BEFORE the tap point (common-mode)
            sweep(5, 1, 9, 8);    // POST  : after the checker tap (relu_out before fm write)
            sweep(6, 1, 9, 23);   // CHK   : checker accumulator
            sweep(7, 1, 9, 23);   // EXP   : expected-checksum accumulator

            // double faults: two PSUM flips at PE8 (raw output), same bit, windows a<b
            for (a = 0; a < 9; a = a + 1)
                for (b = a + 1; b < 9; b = b + 1)
                    for (bt = 0; bt < 20; bt = bt + 1) begin
                        dut.u_fi0.en = 1; dut.u_fi0.site = 1; dut.u_fi0.pe = 8; dut.u_fi0.win = a; dut.u_fi0.bit_i = bt;
                        dut.u_fi1.en = 1; dut.u_fi1.site = 1; dut.u_fi1.pe = 8; dut.u_fi1.win = b; dut.u_fi1.bit_i = bt;
                        run_dut; compare_gold; classify;
                        dbl_n = dbl_n + 1;
                        if (cls == C_MISS) dbl_miss_fm = dbl_miss_fm + 1;
                        if (cls == C_MISS || cls == C_MISSB) dbl_miss_raw = dbl_miss_raw + 1;
                        if (cls == C_DETV || cls == C_DETI) dbl_det = dbl_det + 1;
                        clear_faults;
                    end
        end
        $fclose(fd);

        $display("================ FAULT CAMPAIGN (%0d vectors: %0d,%0d,%0d,%0d) ================", NSEL,
                 sel_list[0], sel_list[1], sel_list[2], sel_list[3]);
        $display("site       |  total | DET_VIS | DET_INV |  MISS | MISS_BEN | NO_EFFECT | FALSE_ALM");
        show_row(0, "PROD");  show_row(1, "PSUM");  show_row(2, "WEIGHT");  show_row(3, "PIXIN");
        show_row(4, "WIN_COMMON"); show_row(5, "POST_TAP"); show_row(6, "CHK_ACC"); show_row(7, "EXP_ACC");
        $display("--- double fault: two same-bit PSUM flips at PE8 in different windows ---");
        $display("runs=%0d detected=%0d undetected(raw corrupted)=%0d of which feature-map corrupted=%0d",
                 dbl_n, dbl_det, dbl_miss_raw, dbl_miss_fm);
        $display("misses/false alarms logged to fi_misses.csv");
        $finish;
    end
    initial begin #2000000000; $display("ERROR: TIMEOUT"); $finish; end
endmodule
