`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fixedbase_context;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic start_ref, done_ref;
    logic start_ht, done_ht;
    logic [255:0] scalar;
    logic signed [319:0] ref_X, ref_Y, ref_Z, ref_T;
    fe17_t ht_X, ht_Y, ht_Z, ht_T;

    fe17_t ref_X17, ref_Y17, ref_Z17, ref_T17;
    logic cmp_start;
    logic cmp_done0, cmp_done1, cmp_done2, cmp_done3;
    fe17_t xz_ref, xz_ht, yz_ref, yz_ht;

    ed25519_fixedbase_context_v2_shared u_ref (
        .clk(clk), .rst_n(rst_n), .start(start_ref), .scalar(scalar),
        .r_X(ref_X), .r_Y(ref_Y), .r_Z(ref_Z), .r_T(ref_T), .done(done_ref)
    );

    ed25519_ht_fixedbase_context u_ht (
        .clk(clk), .rst_n(rst_n), .start(start_ht), .scalar(scalar),
        .r_X(ht_X), .r_Y(ht_Y), .r_Z(ht_Z), .r_T(ht_T), .done(done_ht)
    );

    ed25519_ht_fe10_to_fe17 cX(.fe10(ref_X), .fe17(ref_X17));
    ed25519_ht_fe10_to_fe17 cY(.fe10(ref_Y), .fe17(ref_Y17));
    ed25519_ht_fe10_to_fe17 cZ(.fe10(ref_Z), .fe17(ref_Z17));
    ed25519_ht_fe10_to_fe17 cT(.fe10(ref_T), .fe17(ref_T17));

    ed25519_ht_fe17_mul_pipe m0(.clk(clk), .rst_n(rst_n), .in_valid(cmp_start), .a(ht_X),  .b(ref_Z17), .out_valid(cmp_done0), .out(xz_ht));
    ed25519_ht_fe17_mul_pipe m1(.clk(clk), .rst_n(rst_n), .in_valid(cmp_start), .a(ref_X17), .b(ht_Z),  .out_valid(cmp_done1), .out(xz_ref));
    ed25519_ht_fe17_mul_pipe m2(.clk(clk), .rst_n(rst_n), .in_valid(cmp_start), .a(ht_Y),  .b(ref_Z17), .out_valid(cmp_done2), .out(yz_ht));
    ed25519_ht_fe17_mul_pipe m3(.clk(clk), .rst_n(rst_n), .in_valid(cmp_start), .a(ref_Y17), .b(ht_Z),  .out_valid(cmp_done3), .out(yz_ref));

    task automatic run_case(input logic [255:0] scalar_value);
        int ref_cycles;
        int ht_cycles;
        bit ref_seen;
        bit ht_seen;
        int cycles;
        begin
            scalar = scalar_value;
            @(negedge clk);
            start_ref = 1'b1;
            start_ht = 1'b1;
            @(negedge clk);
            start_ref = 1'b0;
            start_ht = 1'b0;

            ref_cycles = 0;
            ht_cycles = 0;
            cycles = 0;
            ref_seen = 1'b0;
            ht_seen = 1'b0;
            while (!(ref_seen && ht_seen) && cycles < 100000) begin
                @(posedge clk);
                cycles++;
                if (!ref_seen)
                    ref_cycles++;
                if (!ht_seen)
                    ht_cycles++;
                if (done_ref)
                    ref_seen = 1'b1;
                if (done_ht)
                    ht_seen = 1'b1;
            end
            if (!ref_seen) $fatal(1, "ref timeout");
            if (!ht_seen) $fatal(1, "ht timeout");

            @(negedge clk);
            cmp_start = 1'b1;
            @(negedge clk);
            cmp_start = 1'b0;
            while (!(cmp_done0 && cmp_done1 && cmp_done2 && cmp_done3)) @(posedge clk);
            #1;

            if (xz_ht !== xz_ref)
                $fatal(1, "X affine mismatch scalar=%064x ht=%064x ref=%064x htXYZT=%064x %064x %064x %064x refXYZT=%080x %080x %080x %080x", scalar_value, xz_ht, xz_ref, ht_X, ht_Y, ht_Z, ht_T, ref_X, ref_Y, ref_Z, ref_T);
            if (yz_ht !== yz_ref)
                $fatal(1, "Y affine mismatch scalar=%064x ht=%064x ref=%064x", scalar_value, yz_ht, yz_ref);

            $display("PASS fixedbase scalar=%064x ref_cycles=%0d ht_cycles=%0d", scalar_value, ref_cycles, ht_cycles);
            repeat (5) @(posedge clk);
        end
    endtask

    initial begin
        scalar = 256'd0;
        start_ref = 1'b0;
        start_ht = 1'b0;
        cmp_start = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        run_case(256'h6f8eff1f84f125a1e612dede40146d9d5549e02b76356981ef0a589ca4ee9438);
        run_case(256'h4fe94d9006f020a5a3c080d96827fffd3c010ac0f12e7a42cb33284f86837c30);

        $display("PASS tb_ed25519_ht_fixedbase_context");
        $finish;
    end
endmodule
