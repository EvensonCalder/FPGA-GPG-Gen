`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fe17_batch_affine32;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic start;
    logic done;
    logic [255:0] seed_in [0:31];
    fe17_t x [0:31], y [0:31], z [0:31];
    fe17_t t_unused [0:31];
    logic [255:0] expected_public [0:31];
    logic [255:0] seed_out [0:31];
    logic [255:0] public_key [0:31];
    int cycles;

    ed25519_ht_fe17_batch_affine32 dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .seed_in(seed_in), .x_in(x), .y_in(y), .z_in(z),
        .done(done), .seed_out(seed_out), .public_key(public_key)
    );

    task automatic load_vectors;
        int fd;
        int rc;
        string vector_file;
        logic [255:0] raw_x, raw_y, raw_z, raw_t, raw_pub, raw_seed;
        begin
            if (!$value$plusargs("VECTOR_FILE=%s", vector_file))
                vector_file = "sim/ht_batch_affine32_vectors.mem";
            fd = $fopen(vector_file, "r");
            if (fd == 0) $fatal(1, "could not open %s", vector_file);
            for (int i = 0; i < 32; i++) begin
                rc = $fscanf(fd, "%h %h %h %h %h %h\n", raw_x, raw_y, raw_z, raw_t, raw_pub, raw_seed);
                if (rc != 6) $fatal(1, "failed vector %0d rc=%0d", i, rc);
                x[i] = fe17_t'(raw_x); y[i] = fe17_t'(raw_y); z[i] = fe17_t'(raw_z); t_unused[i] = fe17_t'(raw_t);
                expected_public[i] = raw_pub; seed_in[i] = raw_seed;
            end
            $fclose(fd);
        end
    endtask

    initial begin
        load_vectors();
        start = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;
        begin
            cycles = 0;
            while (!done && cycles < 80000) begin @(posedge clk); cycles++; end
            if (!done) $fatal(1, "batch affine32 timeout");
            #1;
            for (int i = 0; i < 32; i++) begin
                if (seed_out[i] !== seed_in[i]) $fatal(1, "seed mismatch i=%0d", i);
                if (public_key[i] !== expected_public[i])
                    $fatal(1, "public mismatch i=%0d got=%064x expected=%064x", i, public_key[i], expected_public[i]);
            end
            $display("PASS tb_ed25519_ht_fe17_batch_affine32 cycles=%0d", cycles);
        end
        $finish;
    end
endmodule
