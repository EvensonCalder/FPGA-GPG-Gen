`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module tb_ed25519_ht_fe17_madd_sched #(
    parameter integer CONTEXTS = 4,
    parameter integer VECTOR_COUNT = 21,
    parameter integer TOTAL_COUNT = 21
);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic [CONTEXTS-1:0] start;
    logic [CONTEXTS-1:0] start_ready;
    logic [CONTEXTS-1:0] done;
    fe17_t p_X [0:CONTEXTS-1], p_Y [0:CONTEXTS-1], p_Z [0:CONTEXTS-1], p_T [0:CONTEXTS-1];
    fe17_t q_yplusx [0:CONTEXTS-1], q_yminusx [0:CONTEXTS-1], q_xy2d [0:CONTEXTS-1];
    fe17_t r_X [0:CONTEXTS-1], r_Y [0:CONTEXTS-1], r_Z [0:CONTEXTS-1], r_T [0:CONTEXTS-1];
    logic [255:0] vec [0:VECTOR_COUNT-1][0:10];
    int ctx_vec [0:CONTEXTS-1];
    int accepted;
    int produced;
    int cycles;

    ed25519_ht_fe17_madd_sched #(
        .CONTEXTS(CONTEXTS)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .start_ready(start_ready),
        .p_X(p_X), .p_Y(p_Y), .p_Z(p_Z), .p_T(p_T),
        .q_yplusx(q_yplusx), .q_yminusx(q_yminusx), .q_xy2d(q_xy2d),
        .done(done), .r_X(r_X), .r_Y(r_Y), .r_Z(r_Z), .r_T(r_T)
    );

    task automatic load_vectors;
        int fd;
        int rc;
        string vector_file;
        begin
            if (!$value$plusargs("VECTOR_FILE=%s", vector_file))
                vector_file = "sim/ht_fe17_madd_vectors.mem";
            fd = $fopen(vector_file, "r");
            if (fd == 0)
                $fatal(1, "could not open %s", vector_file);
            for (int i = 0; i < VECTOR_COUNT; i++) begin
                rc = $fscanf(fd, "%h %h %h %h %h %h %h %h %h %h %h\n",
                    vec[i][0], vec[i][1], vec[i][2], vec[i][3], vec[i][4], vec[i][5], vec[i][6],
                    vec[i][7], vec[i][8], vec[i][9], vec[i][10]);
                if (rc != 11)
                    $fatal(1, "failed vector %0d rc=%0d", i, rc);
            end
            $fclose(fd);
        end
    endtask

    task automatic drive_ctx(input int c, input int item);
        int v;
        begin
            v = item % VECTOR_COUNT;
            start[c] = 1'b1;
            p_X[c] = fe17_t'(vec[v][0]);
            p_Y[c] = fe17_t'(vec[v][1]);
            p_Z[c] = fe17_t'(vec[v][2]);
            p_T[c] = fe17_t'(vec[v][3]);
            q_yplusx[c] = fe17_t'(vec[v][4]);
            q_yminusx[c] = fe17_t'(vec[v][5]);
            q_xy2d[c] = fe17_t'(vec[v][6]);
            ctx_vec[c] = v;
        end
    endtask

    task automatic check_ctx(input int c);
        int v;
        begin
            v = ctx_vec[c];
            if (r_X[c] !== fe17_t'(vec[v][7]))
                $fatal(1, "X mismatch ctx=%0d vector=%0d got=%064x expected=%064x", c, v, r_X[c], vec[v][7]);
            if (r_Y[c] !== fe17_t'(vec[v][8]))
                $fatal(1, "Y mismatch ctx=%0d vector=%0d got=%064x expected=%064x", c, v, r_Y[c], vec[v][8]);
            if (r_Z[c] !== fe17_t'(vec[v][9]))
                $fatal(1, "Z mismatch ctx=%0d vector=%0d got=%064x expected=%064x", c, v, r_Z[c], vec[v][9]);
            if (r_T[c] !== fe17_t'(vec[v][10]))
                $fatal(1, "T mismatch ctx=%0d vector=%0d got=%064x expected=%064x", c, v, r_T[c], vec[v][10]);
            produced++;
        end
    endtask

    initial begin
        load_vectors();
        start = '0;
        accepted = 0;
        produced = 0;
        cycles = 0;
        for (int i = 0; i < CONTEXTS; i++) begin
            p_X[i] = '0; p_Y[i] = '0; p_Z[i] = '0; p_T[i] = '0;
            q_yplusx[i] = '0; q_yminusx[i] = '0; q_xy2d[i] = '0;
            ctx_vec[i] = -1;
        end

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        @(negedge clk);
        for (int c = 0; c < CONTEXTS; c++) begin
            if (accepted < TOTAL_COUNT && start_ready[c]) begin
                drive_ctx(c, accepted);
                accepted++;
            end
        end

        while (produced < TOTAL_COUNT && cycles < 10000) begin
            @(posedge clk);
            #1;
            cycles++;
            for (int c = 0; c < CONTEXTS; c++) begin
                if (done[c])
                    check_ctx(c);
            end

            @(negedge clk);
            start = '0;
            for (int c = 0; c < CONTEXTS; c++) begin
                if (accepted < TOTAL_COUNT && start_ready[c]) begin
                    drive_ctx(c, accepted);
                    accepted++;
                end
            end
        end

        if (produced != TOTAL_COUNT)
            $fatal(1, "timeout accepted=%0d produced=%0d cycles=%0d", accepted, produced, cycles);
        $display("PASS tb_ed25519_ht_fe17_madd_sched contexts=%0d total=%0d cycles=%0d avg_cycles=%0d",
                 CONTEXTS, TOTAL_COUNT, cycles, cycles / TOTAL_COUNT);
        $finish;
    end
endmodule
