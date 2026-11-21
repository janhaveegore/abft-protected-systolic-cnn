`include "cnn_params.vh"
`timescale 1ns/1ps
`include "vec_path.vh"
// Functional + ABFT fault-free testbench for cnn_top_sys.
// Per vector: reset, load, run (run 1) then re-start WITHOUT reset (run 2, tests D6).
// Checks: 8-bit feature map, RAW 20-bit outputs (pre-ReLU), checker sum, expected checksum,
//         abft_err must be 0 (no false alarms), latency.
module tb_sys_func;
    parameter NV = 57;
    reg clk, reset, img_we, ker_we, start;
    reg [`IMG_ADDR_W-1:0] img_waddr; reg [`ACT_W-1:0] img_din;
    reg [`KER_ADDR_W-1:0] ker_waddr; reg signed [`WEIGHT_W-1:0] ker_din;
    reg [`OUT_ADDR_W-1:0] fm_raddr;
    wire done, abft_err; wire [`OUT_DATA_W-1:0] fm_dout;

    cnn_top_sys dut(.clk(clk),.reset(reset),.img_we(img_we),.img_waddr(img_waddr),.img_din(img_din),
        .ker_we(ker_we),.ker_waddr(ker_waddr),.ker_din(ker_din),.start(start),.done(done),
        .fm_raddr(fm_raddr),.fm_dout(fm_dout),.abft_err(abft_err));

    `ifdef DUMP
    initial begin $dumpfile("sys_func.vcd"); $dumpvars(0, tb_sys_func); end
    `endif
    initial clk = 0;
    always #5 clk = ~clk;

    reg [7:0]  img_v [0:NV*25-1];
    reg [7:0]  ker_v [0:NV*9-1];
    reg [7:0]  fm_v  [0:NV*9-1];
    reg [19:0] raw_v [0:NV*9-1];
    reg [22:0] cs_v  [0:NV-1];

    // raw-output capture (testbench observes the pre-ReLU value when it is valid)
    reg [19:0] raw_cap [0:8];
    integer rcnt;
    always @(posedge clk) begin
        if (dut.start_accept) rcnt = 0;
        if (dut.out_valid) begin raw_cap[rcnt] = dut.p8; rcnt = rcnt + 1; end
    end

    // latency (same definition as the baseline testbench)
    integer lat, cnt, lat_min, lat_max, nwr_bad;
    reg running, lat_valid;
    always @(posedge clk) begin
        if (!running && start) begin running = 1; lat_valid = 0; cnt = 1; end
        else if (running) begin
            if (done) begin lat = cnt; lat_valid = 1; running = 0; end
            else cnt = cnt + 1;
        end
    end

    integer v, i, run, e_fm, e_raw, e_cs, tot_fm, tot_raw, tot_cs, tot_fa, n_runs;

    task do_run(input integer vec);
    begin
        start = 1; @(negedge clk); start = 0;
        wait (lat_valid == 1); @(negedge clk);
        e_fm = 0; e_raw = 0; e_cs = 0;
        for (i = 0; i < 9; i = i + 1) begin
            fm_raddr = i; #1;
            if (fm_dout !== fm_v[vec*9+i]) begin
                e_fm = e_fm + 1;
                $display("  vec %0d run %0d FM  mismatch addr %0d: exp %0h got %0h", vec, run, i, fm_v[vec*9+i], fm_dout);
            end
            if (raw_cap[i] !== raw_v[vec*9+i]) begin
                e_raw = e_raw + 1;
                $display("  vec %0d run %0d RAW mismatch win %0d: exp %0h got %0h", vec, run, i, raw_v[vec*9+i], raw_cap[i]);
            end
        end
        if (dut.u_chk.sum !== cs_v[vec] || dut.u_exp.exp_cs !== cs_v[vec]) begin
            e_cs = 1;
            $display("  vec %0d run %0d CHECKSUM mismatch: model %0h  computed %0h  expected %0h", vec, run, cs_v[vec], dut.u_chk.sum, dut.u_exp.exp_cs);
        end
        tot_fm = tot_fm + e_fm; tot_raw = tot_raw + e_raw; tot_cs = tot_cs + e_cs;
        if (abft_err !== 1'b0) begin tot_fa = tot_fa + 1; $display("  vec %0d run %0d FALSE ALARM (abft_err=1)", vec, run); end
        if (lat < lat_min) lat_min = lat; if (lat > lat_max) lat_max = lat;
        n_runs = n_runs + 1;
        if (vec < 2 && run == 1) $display("vec %0d run %0d: fm_err=%0d raw_err=%0d cs_err=%0d abft_err=%0b latency=%0d", vec, run, e_fm, e_raw, e_cs, abft_err, lat);
    end
    endtask

    initial begin
        $readmemh({`VEC_DIR, "/img.hex"}, img_v); $readmemh({`VEC_DIR, "/ker.hex"}, ker_v);
        $readmemh({`VEC_DIR, "/fm.hex"},  fm_v);  $readmemh({`VEC_DIR, "/raw.hex"}, raw_v);
        $readmemh({`VEC_DIR, "/cs.hex"},  cs_v);
        tot_fm = 0; tot_raw = 0; tot_cs = 0; tot_fa = 0; n_runs = 0; lat_min = 9999; lat_max = 0;
        running = 0; lat_valid = 0; rcnt = 0;
        reset = 1; img_we = 0; ker_we = 0; start = 0; img_waddr = 0; img_din = 0; ker_waddr = 0; ker_din = 0; fm_raddr = 0;
        repeat (3) @(negedge clk);
        for (v = 0; v < NV; v = v + 1) begin
            reset = 1; repeat (2) @(negedge clk); reset = 0; @(negedge clk);
            img_we = 1;
            for (i = 0; i < 25; i = i + 1) begin img_waddr = i; img_din = img_v[v*25+i]; @(negedge clk); end
            img_we = 0; ker_we = 1;
            for (i = 0; i < 9; i = i + 1) begin ker_waddr = i; ker_din = ker_v[v*9+i]; @(negedge clk); end
            ker_we = 0; @(negedge clk);
            run = 1; do_run(v);
            @(negedge clk);
            run = 2; do_run(v);          // re-start without reset
            @(negedge clk);
        end
        $display("================================================");
        $display("SYSTOLIC+ABFT (fault-free): %0d vectors x 2 runs = %0d runs", NV, n_runs);
        $display("  feature-map mismatches : %0d", tot_fm);
        $display("  raw-output mismatches  : %0d", tot_raw);
        $display("  checksum mismatches    : %0d", tot_cs);
        $display("  false alarms           : %0d", tot_fa);
        $display("  latency (edges, start-edge..done-registered): min=%0d max=%0d", lat_min, lat_max);
        if (tot_fm == 0 && tot_raw == 0 && tot_cs == 0 && tot_fa == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL");
        $finish;
    end
    initial begin #20000000; $display("ERROR: TIMEOUT"); $finish; end
endmodule
