`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;
import ed25519_ht_scalar_sched_pkg::*;

module tb_ed25519_ht_scalar_mul_issue2;
    localparam int VECTOR_COUNT = 16;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic issue0_valid, issue1_valid;
    scalar_mul_tag_t issue0_tag, issue1_tag;
    fe17_t issue0_a, issue0_b, issue1_a, issue1_b;
    logic retire0_valid, retire1_valid;
    scalar_mul_tag_t retire0_tag, retire1_tag;
    fe17_t retire0_y, retire1_y;
    logic [255:0] vec_a [0:VECTOR_COUNT-1];
    logic [255:0] vec_b [0:VECTOR_COUNT-1];
    logic [255:0] vec_c [0:VECTOR_COUNT-1];
    int send_idx;
    int recv_count;

    ed25519_ht_scalar_mul_issue2 dut (
        .clk(clk), .rst_n(rst_n),
        .issue0_valid(issue0_valid), .issue0_tag(issue0_tag), .issue0_a(issue0_a), .issue0_b(issue0_b),
        .issue1_valid(issue1_valid), .issue1_tag(issue1_tag), .issue1_a(issue1_a), .issue1_b(issue1_b),
        .retire0_valid(retire0_valid), .retire0_tag(retire0_tag), .retire0_y(retire0_y),
        .retire1_valid(retire1_valid), .retire1_tag(retire1_tag), .retire1_y(retire1_y)
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
                    $fatal(1, "failed vector %0d rc=%0d", i, rc);
            end
            $fclose(fd);
        end
    endtask

    task automatic check_retire(input scalar_mul_tag_t tag, input fe17_t y);
        int idx;
        begin
            idx = tag.ctx;
            if (idx < 0 || idx >= VECTOR_COUNT)
                $fatal(1, "retire tag out of range ctx=%0d op=%0d", tag.ctx, tag.op);
            if (y !== fe17_t'(vec_c[idx]))
                $fatal(1, "retire mismatch ctx=%0d got=%064x expected=%064x", idx, y, fe17_t'(vec_c[idx]));
            recv_count++;
        end
    endtask

    initial begin
        load_vectors();
        issue0_valid = 1'b0;
        issue1_valid = 1'b0;
        issue0_tag = '0;
        issue1_tag = '0;
        issue0_a = '0; issue0_b = '0;
        issue1_a = '0; issue1_b = '0;
        send_idx = 0;
        recv_count = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        while (recv_count < VECTOR_COUNT) begin
            @(negedge clk);
            issue0_valid = 1'b0;
            issue1_valid = 1'b0;
            if (send_idx < VECTOR_COUNT) begin
                issue0_valid = 1'b1;
                issue0_tag.ctx = send_idx[4:0];
                issue0_tag.op = OP_MADD_A;
                issue0_a = fe17_t'(vec_a[send_idx]);
                issue0_b = fe17_t'(vec_b[send_idx]);
                send_idx++;
            end
            if (send_idx < VECTOR_COUNT) begin
                issue1_valid = 1'b1;
                issue1_tag.ctx = send_idx[4:0];
                issue1_tag.op = OP_MADD_B;
                issue1_a = fe17_t'(vec_a[send_idx]);
                issue1_b = fe17_t'(vec_b[send_idx]);
                send_idx++;
            end

            @(posedge clk);
            if (retire0_valid)
                check_retire(retire0_tag, retire0_y);
            if (retire1_valid)
                check_retire(retire1_tag, retire1_y);
        end

        $display("PASS tb_ed25519_ht_scalar_mul_issue2 vectors=%0d", recv_count);
        $finish;
    end
endmodule
