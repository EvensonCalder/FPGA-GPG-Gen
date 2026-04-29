`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fe17_invert_pow;
    localparam int VECTOR_COUNT = 8;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic start;
    logic busy;
    logic done;
    fe17_t z;
    fe17_t inv_z;
    logic check_valid;
    logic check_done;
    fe17_t check_prod;
    logic [255:0] vec_z [0:VECTOR_COUNT-1];

    ed25519_ht_fe17_invert_pow dut (
        .clk(clk), .rst_n(rst_n), .start(start), .z(z),
        .busy(busy), .done(done), .out(inv_z)
    );

    ed25519_ht_fe17_mul_pipe u_check (
        .clk(clk), .rst_n(rst_n), .in_valid(check_valid),
        .a(z), .b(inv_z), .out_valid(check_done), .out(check_prod)
    );

    initial begin
        vec_z[0] = 256'h1;
        vec_z[1] = 256'h2;
        vec_z[2] = 256'h5;
        vec_z[3] = 256'h123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        vec_z[4] = 256'h7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffec;
        vec_z[5] = 256'h4000000000000000000000000000000000000000000000000000000000000000;
        vec_z[6] = 256'h1111111111111111111111111111111111111111111111111111111111111111;
        vec_z[7] = 256'h6f8eff1f84f125a1e612dede40146d9d5549e02b76356981ef0a589ca4ee9438;

        start = 1'b0;
        check_valid = 1'b0;
        z = '0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        for (int i = 0; i < VECTOR_COUNT; i++) begin
            int cycles;
            z = fe17_t'(vec_z[i]);
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            cycles = 0;
            while (!done && cycles < 40000) begin
                @(posedge clk);
                cycles++;
            end
            if (!done)
                $fatal(1, "invert timeout vector=%0d", i);
            @(negedge clk); check_valid = 1'b1;
            @(negedge clk); check_valid = 1'b0;
            while (!check_done) @(posedge clk);
            #1;
            if (check_prod !== fe17_t'(255'd1))
                $fatal(1, "inverse check mismatch vector=%0d z=%064x inv=%064x prod=%064x cycles=%0d", i, z, inv_z, check_prod, cycles);
            $display("PASS invert vector=%0d cycles=%0d", i, cycles);
            repeat (3) @(posedge clk);
        end

        $display("PASS tb_ed25519_ht_fe17_invert_pow vectors=%0d", VECTOR_COUNT);
        $finish;
    end
endmodule
