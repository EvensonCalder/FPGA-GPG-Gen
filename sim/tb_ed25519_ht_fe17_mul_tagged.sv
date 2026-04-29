`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fe17_mul_tagged;
    localparam int VECTOR_COUNT = 45;
    localparam int TAG_BITS = 6;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic in_valid;
    logic [TAG_BITS-1:0] in_tag;
    fe17_t a, b;
    logic out_valid;
    logic [TAG_BITS-1:0] out_tag;
    fe17_t out;

    logic [255:0] vec_a [0:VECTOR_COUNT-1];
    logic [255:0] vec_b [0:VECTOR_COUNT-1];
    logic [255:0] vec_c [0:VECTOR_COUNT-1];
    logic [TAG_BITS-1:0] expected_tag_pipe [0:31];
    logic valid_pipe [0:31];
    logic [TAG_BITS-1:0] expected_tag_in;
    int send_idx;
    int recv_idx;

    ed25519_ht_fe17_mul_tagged #(.TAG_BITS(TAG_BITS)) dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_tag(in_tag),
        .a(a), .b(b), .out_valid(out_valid), .out_tag(out_tag), .out(out)
    );

    task automatic load_vectors;
        int fd;
        int rc;
        string vector_file;
        begin
            if (!$value$plusargs("VECTOR_FILE=%s", vector_file))
                vector_file = "sim/ht_fe17_mul_vectors.mem";
            fd = $fopen(vector_file, "r");
            if (fd == 0)
                $fatal(1, "could not open %s", vector_file);
            for (int i = 0; i < VECTOR_COUNT; i++) begin
                rc = $fscanf(fd, "%h %h %h\n", vec_a[i], vec_b[i], vec_c[i]);
                if (rc != 3)
                    $fatal(1, "failed to read vector %0d rc=%0d", i, rc);
            end
            $fclose(fd);
        end
    endtask

    initial begin
        load_vectors();
        in_valid = 1'b0;
        in_tag = '0;
        expected_tag_in = '0;
        a = '0;
        b = '0;
        send_idx = 0;
        recv_idx = 0;
        for (int i = 0; i < 32; i++) begin
            expected_tag_pipe[i] = '0;
            valid_pipe[i] = 1'b0;
        end
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        while (recv_idx < VECTOR_COUNT) begin
            @(negedge clk);
            if (send_idx < VECTOR_COUNT) begin
                in_valid = 1'b1;
                in_tag = TAG_BITS'(send_idx);
                expected_tag_in = TAG_BITS'(send_idx);
                a = fe17_t'(vec_a[send_idx]);
                b = fe17_t'(vec_b[send_idx]);
                send_idx++;
            end else begin
                in_valid = 1'b0;
                in_tag = '0;
                expected_tag_in = '0;
                a = '0;
                b = '0;
            end

            @(posedge clk);
            if (out_valid) begin
                if (!valid_pipe[31])
                    $fatal(1, "unexpected output valid");
                if (out_tag !== expected_tag_pipe[31])
                    $fatal(1, "tag mismatch got=%0d expected=%0d recv=%0d", out_tag, expected_tag_pipe[31], recv_idx);
                if (out !== fe17_t'(vec_c[out_tag]))
                    $fatal(1, "tag %0d mismatch got=%064x expected=%064x recv=%0d", out_tag, out, fe17_t'(vec_c[out_tag]), recv_idx);
                recv_idx++;
            end

            for (int i = 31; i > 0; i--) begin
                expected_tag_pipe[i] = expected_tag_pipe[i - 1];
                valid_pipe[i] = valid_pipe[i - 1];
            end
            expected_tag_pipe[0] = expected_tag_in;
            valid_pipe[0] = in_valid;
        end

        $display("PASS tb_ed25519_ht_fe17_mul_tagged vectors=%0d", recv_idx);
        $finish;
    end
endmodule
