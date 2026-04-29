`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fixedbase_sched #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer CONTEXTS = 16,
    parameter integer TOTAL_COUNT = 32
);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic ref_start, ref_done;
    logic [255:0] ref_scalar;
    fe17_t ref_X, ref_Y, ref_Z, ref_T;
    fe17_t exp_X [0:1], exp_Y [0:1], exp_Z [0:1], exp_T [0:1];

    logic scalar_valid, scalar_ready;
    logic [255:0] scalar;
    logic scalar_tag;
    logic point_valid;
    logic point_tag;
    fe17_t point_x, point_y, point_z;
    int accepted, produced, cycles;

    logic [255:0] scalars [0:1];

    ed25519_ht_fixedbase_context #(
        .INIT_FILE(INIT_FILE), .MUL_LANES(2)
    ) u_ref (
        .clk(clk), .rst_n(rst_n), .start(ref_start), .scalar(ref_scalar),
        .r_X(ref_X), .r_Y(ref_Y), .r_Z(ref_Z), .r_T(ref_T), .done(ref_done)
    );

    ed25519_ht_fixedbase_sched #(
        .INIT_FILE(INIT_FILE), .CONTEXTS(CONTEXTS)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .scalar_valid(scalar_valid), .scalar_ready(scalar_ready), .scalar(scalar), .scalar_tag(scalar_tag),
        .point_valid(point_valid), .point_ready(1'b1), .point_tag(point_tag),
        .point_x(point_x), .point_y(point_y), .point_z(point_z)
    );

    task automatic compute_expected(input int idx);
        int wait_cycles;
        begin
            ref_scalar = scalars[idx];
            @(negedge clk); ref_start = 1'b1;
            @(negedge clk); ref_start = 1'b0;
            wait_cycles = 0;
            while (!ref_done && wait_cycles < 100000) begin
                @(posedge clk);
                wait_cycles++;
            end
            if (!ref_done)
                $fatal(1, "reference timeout idx=%0d", idx);
            #1;
            exp_X[idx] = ref_X;
            exp_Y[idx] = ref_Y;
            exp_Z[idx] = ref_Z;
            exp_T[idx] = ref_T;
            $display("reference idx=%0d cycles=%0d", idx, wait_cycles);
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic check_point;
        int idx;
        begin
            idx = point_tag;
            if (point_x !== exp_X[idx])
                $fatal(1, "X mismatch idx=%0d got=%064x expected=%064x", idx, point_x, exp_X[idx]);
            if (point_y !== exp_Y[idx])
                $fatal(1, "Y mismatch idx=%0d got=%064x expected=%064x", idx, point_y, exp_Y[idx]);
            if (point_z !== exp_Z[idx])
                $fatal(1, "Z mismatch idx=%0d got=%064x expected=%064x", idx, point_z, exp_Z[idx]);
            produced++;
        end
    endtask

    initial begin
        scalars[0] = 256'h6f8eff1f84f125a1e612dede40146d9d5549e02b76356981ef0a589ca4ee9438;
        scalars[1] = 256'h4fe94d9006f020a5a3c080d96827fffd3c010ac0f12e7a42cb33284f86837c30;
        ref_start = 1'b0;
        ref_scalar = 256'd0;
        scalar_valid = 1'b0;
        scalar = 256'd0;
        scalar_tag = 1'b0;
        accepted = 0;
        produced = 0;
        cycles = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        compute_expected(0);
        compute_expected(1);

        @(negedge clk);
        scalar_valid = 1'b1;
        scalar = scalars[0];
        scalar_tag = 1'b0;
        while (produced < TOTAL_COUNT && cycles < 200000) begin
            @(posedge clk);
            #1;
            cycles++;
            if (scalar_valid && scalar_ready) begin
                accepted++;
                if (accepted < TOTAL_COUNT) begin
                    scalar = scalars[accepted & 1];
                    scalar_tag = accepted[0];
                end else begin
                    scalar_valid = 1'b0;
                end
            end
            if (point_valid)
                check_point();
        end

        if (produced != TOTAL_COUNT)
            $fatal(1, "timeout accepted=%0d produced=%0d cycles=%0d", accepted, produced, cycles);
        $display("PASS tb_ed25519_ht_fixedbase_sched contexts=%0d total=%0d cycles=%0d avg_cycles=%0d",
                 CONTEXTS, TOTAL_COUNT, cycles, cycles / TOTAL_COUNT);
        $finish;
    end
endmodule
