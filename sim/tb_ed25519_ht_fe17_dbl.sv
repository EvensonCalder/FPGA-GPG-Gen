`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fe17_dbl;
    localparam int VECTOR_COUNT = 25;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic start, busy, done;
    fe17_t p_X, p_Y, p_Z, p_T;
    fe17_t r_X, r_Y, r_Z, r_T;
    logic [255:0] vec [0:VECTOR_COUNT-1][0:7];

    ed25519_ht_fe17_dbl dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .p_X(p_X), .p_Y(p_Y), .p_Z(p_Z), .p_T(p_T),
        .busy(busy), .done(done),
        .r_X(r_X), .r_Y(r_Y), .r_Z(r_Z), .r_T(r_T)
    );

    task automatic load_vectors;
        int fd, rc;
        string vector_file;
        begin
            if (!$value$plusargs("VECTOR_FILE=%s", vector_file))
                vector_file = "sim/ht_fe17_dbl_vectors.mem";
            fd = $fopen(vector_file, "r");
            if (fd == 0)
                $fatal(1, "could not open %s", vector_file);
            for (int i = 0; i < VECTOR_COUNT; i++) begin
                rc = $fscanf(fd, "%h %h %h %h %h %h %h %h\n",
                    vec[i][0], vec[i][1], vec[i][2], vec[i][3],
                    vec[i][4], vec[i][5], vec[i][6], vec[i][7]);
                if (rc != 8)
                    $fatal(1, "failed vector %0d rc=%0d", i, rc);
            end
            $fclose(fd);
        end
    endtask

    task automatic run_vector(input int idx);
        int cycles;
        begin
            p_X = fe17_t'(vec[idx][0]);
            p_Y = fe17_t'(vec[idx][1]);
            p_Z = fe17_t'(vec[idx][2]);
            p_T = fe17_t'(vec[idx][3]);

            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            cycles = 0;
            while (!done && cycles < 1000) begin
                @(posedge clk);
                cycles++;
            end
            if (!done)
                $fatal(1, "timeout vector %0d", idx);
            #1;
            if (r_X !== fe17_t'(vec[idx][4]))
                $fatal(1, "X mismatch vector=%0d got=%064x expected=%064x", idx, r_X, vec[idx][4]);
            if (r_Y !== fe17_t'(vec[idx][5]))
                $fatal(1, "Y mismatch vector=%0d got=%064x expected=%064x", idx, r_Y, vec[idx][5]);
            if (r_Z !== fe17_t'(vec[idx][6]))
                $fatal(1, "Z mismatch vector=%0d got=%064x expected=%064x", idx, r_Z, vec[idx][6]);
            if (r_T !== fe17_t'(vec[idx][7]))
                $fatal(1, "T mismatch vector=%0d got=%064x expected=%064x", idx, r_T, vec[idx][7]);
            $display("PASS dbl vector=%0d cycles=%0d", idx, cycles);
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        load_vectors();
        start = 1'b0;
        p_X = '0; p_Y = '0; p_Z = '0; p_T = '0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);
        for (int i = 0; i < VECTOR_COUNT; i++)
            run_vector(i);
        $display("PASS tb_ed25519_ht_fe17_dbl vectors=%0d", VECTOR_COUNT);
        $finish;
    end
endmodule
