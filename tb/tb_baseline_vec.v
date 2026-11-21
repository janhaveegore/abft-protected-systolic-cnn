`include "cnn_params.vh"
`timescale 1ns/1ps
`include "vec_path.vh"
// Vector-driven baseline testbench: functional check + cycle count (testbench-only instrumentation).
module tb_baseline_vec;
    parameter NV = 57;
    reg clk, reset, img_we, ker_we, start;
    reg [`IMG_ADDR_W-1:0] img_waddr; reg [`ACT_W-1:0] img_din;
    reg [`KER_ADDR_W-1:0] ker_waddr; reg signed [`WEIGHT_W-1:0] ker_din;
    reg [`OUT_ADDR_W-1:0] fm_raddr;
    wire done; wire [`OUT_DATA_W-1:0] fm_dout;

    cnn_top dut(.clk(clk),.reset(reset),.img_we(img_we),.img_waddr(img_waddr),.img_din(img_din),
        .ker_we(ker_we),.ker_waddr(ker_waddr),.ker_din(ker_din),.start(start),.done(done),
        .fm_raddr(fm_raddr),.fm_dout(fm_dout));

    `ifdef DUMP
    initial begin $dumpfile("baseline.vcd"); $dumpvars(0, tb_baseline_vec); end
    `endif
    initial clk = 0;
    always #5 clk = ~clk;

    reg [7:0] img_v [0:NV*25-1];
    reg [7:0] ker_v [0:NV*9-1];
    reg [7:0] fm_v  [0:NV*9-1];

    integer v, i, errors, tot_err, lat, cnt, nwr, badwr, lat_min, lat_max;
    reg running, lat_valid;

    // latency: edge where start is sampled = edge 1; latency = edges up to and incl. the edge that registers done
    always @(posedge clk) begin
        if (!running && start) begin running = 1; lat_valid = 0; cnt = 1; nwr = 0; badwr = 0; end
        else if (running) begin
            if (done) begin lat = cnt; lat_valid = 1; running = 0; end
            else cnt = cnt + 1;
        end
        if (running && dut.fm_we) begin nwr = nwr + 1; if (dut.fm_waddr >= `OUT_SIZE) badwr = badwr + 1; end
    end

    initial begin
        $readmemh({`VEC_DIR, "/img.hex"}, img_v); $readmemh({`VEC_DIR, "/ker.hex"}, ker_v); $readmemh({`VEC_DIR, "/fm.hex"}, fm_v);
        tot_err = 0; lat_min = 9999; lat_max = 0; running = 0; lat_valid = 0;
        reset=1; img_we=0; ker_we=0; start=0; img_waddr=0; img_din=0; ker_waddr=0; ker_din=0; fm_raddr=0;
        repeat (3) @(negedge clk);
        for (v = 0; v < NV; v = v + 1) begin
            reset = 1; repeat (2) @(negedge clk); reset = 0; @(negedge clk);
            img_we = 1;
            for (i = 0; i < 25; i = i + 1) begin img_waddr = i; img_din = img_v[v*25+i]; @(negedge clk); end
            img_we = 0; ker_we = 1;
            for (i = 0; i < 9; i = i + 1) begin ker_waddr = i; ker_din = ker_v[v*9+i]; @(negedge clk); end
            ker_we = 0; @(negedge clk);
            start = 1; @(negedge clk); start = 0;
            wait (lat_valid == 1); @(negedge clk);
            errors = 0;
            for (i = 0; i < 9; i = i + 1) begin
                fm_raddr = i; #1;
                if (fm_dout !== fm_v[v*9+i]) begin
                    errors = errors + 1;
                    $display("  vec %0d MISMATCH addr %0d: exp %0h got %0h", v, i, fm_v[v*9+i], fm_dout);
                end
            end
            tot_err = tot_err + errors;
            if (lat < lat_min) lat_min = lat; if (lat > lat_max) lat_max = lat;
            if (v < 3 || errors != 0 || badwr != 0)
                $display("vec %0d: errors=%0d latency=%0d fm_we_pulses=%0d out_of_range_writes=%0d", v, errors, lat, nwr, badwr);
            @(negedge clk);
        end
        $display("================================================");
        $display("BASELINE: %0d vectors, total mismatches=%0d", NV, tot_err);
        $display("BASELINE latency (start-edge..done-registered, edges): min=%0d max=%0d", lat_min, lat_max);
        if (tot_err == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
    initial begin #2000000; $display("ERROR: TIMEOUT"); $finish; end
endmodule
