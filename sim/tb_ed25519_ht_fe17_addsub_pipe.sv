`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fe17_addsub_pipe;
    localparam int VECTOR_COUNT = 108;
    localparam int LATENCY = 2;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic in_valid;
    logic sub;
    fe17_t a;
    fe17_t b;
    logic out_valid;
    fe17_t out;

    logic vec_sub [0:VECTOR_COUNT-1];
    logic [255:0] vec_a [0:VECTOR_COUNT-1];
    logic [255:0] vec_b [0:VECTOR_COUNT-1];
    logic [255:0] vec_c [0:VECTOR_COUNT-1];
    fe17_t expected_pipe [0:LATENCY-1];
    logic valid_pipe [0:LATENCY-1];
    fe17_t expected_in;
    int send_idx;
    int recv_idx;

    ed25519_ht_fe17_addsub_pipe dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .sub(sub),
        .a(a), .b(b), .out_valid(out_valid), .out(out)
    );

    task automatic load_vectors;
        int fd;
        int rc;
        string vector_file;
        begin
            if (!$value$plusargs("VECTOR_FILE=%s", vector_file))
                vector_file = "sim/ht_fe17_addsub_vectors.mem";
            fd = $fopen(vector_file, "r");
            if (fd == 0)
                $fatal(1, "could not open %s", vector_file);
            for (int i = 0; i < VECTOR_COUNT; i++) begin
                rc = $fscanf(fd, "%b %h %h %h\n", vec_sub[i], vec_a[i], vec_b[i], vec_c[i]);
                if (rc != 4)
                    $fatal(1, "failed vector %0d rc=%0d", i, rc);
            end
            $fclose(fd);
        end
    endtask

    initial begin
        load_vectors();
        in_valid = 1'b0;
        sub = 1'b0;
        a = '0;
        b = '0;
        expected_in = '0;
        send_idx = 0;
        recv_idx = 0;
        for (int i = 0; i < LATENCY; i++) begin
            valid_pipe[i] = 1'b0;
            expected_pipe[i] = '0;
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        while (recv_idx < VECTOR_COUNT) begin
            @(negedge clk);
            if (send_idx < VECTOR_COUNT) begin
                in_valid = 1'b1;
                sub = vec_sub[send_idx];
                a = fe17_t'(vec_a[send_idx]);
                b = fe17_t'(vec_b[send_idx]);
                expected_in = fe17_t'(vec_c[send_idx]);
                send_idx++;
            end else begin
                in_valid = 1'b0;
                sub = 1'b0;
                a = '0;
                b = '0;
                expected_in = '0;
            end

            @(posedge clk);
            if (out_valid) begin
                if (!valid_pipe[LATENCY - 1])
                    $fatal(1, "unexpected output valid");
                if (out !== expected_pipe[LATENCY - 1])
                    $fatal(1, "vector %0d mismatch got=%064x expected=%064x", recv_idx, out, expected_pipe[LATENCY - 1]);
                recv_idx++;
            end

            for (int i = LATENCY - 1; i > 0; i--) begin
                valid_pipe[i] = valid_pipe[i - 1];
                expected_pipe[i] = expected_pipe[i - 1];
            end
            valid_pipe[0] = in_valid;
            expected_pipe[0] = expected_in;
        end

        $display("PASS tb_ed25519_ht_fe17_addsub_pipe vectors=%0d", recv_idx);
        $finish;
    end
endmodule
