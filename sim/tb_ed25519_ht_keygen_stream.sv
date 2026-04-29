`timescale 1ns / 1ps

module tb_ed25519_ht_keygen_stream #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1,
    parameter integer LANES = 2,
    parameter bit NATIVE_COMPRESS = 1'b0,
    parameter bit BATCH_COMPRESS = 1'b0,
    parameter integer BATCH_SIZE = 8,
    parameter bit MULTI_CONTEXT_SCALAR = 1'b0,
    parameter integer SCALAR_CONTEXTS = 16,
    parameter integer BURST_COUNT = 8
);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic seed_valid;
    logic seed_ready;
    logic [255:0] seed;
    logic out_valid;
    logic out_ready;
    logic [255:0] out_seed;
    logic [255:0] out_public_key;
    logic [63:0] accepted_count;
    logic [63:0] produced_count;
    logic [63:0] stall_seed_count;
    logic [63:0] stall_output_count;

    ed25519_ht_keygen_stream #(
        .INIT_FILE(INIT_FILE),
        .LANES(LANES),
        .MUL_LANES(MUL_LANES),
        .NATIVE_COMPRESS(NATIVE_COMPRESS),
        .BATCH_COMPRESS(BATCH_COMPRESS),
        .BATCH_SIZE(BATCH_SIZE),
        .MULTI_CONTEXT_SCALAR(MULTI_CONTEXT_SCALAR),
        .SCALAR_CONTEXTS(SCALAR_CONTEXTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .seed_valid(seed_valid),
        .seed_ready(seed_ready),
        .seed(seed),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_seed(out_seed),
        .out_public_key(out_public_key),
        .accepted_count(accepted_count),
        .produced_count(produced_count),
        .stall_seed_count(stall_seed_count),
        .stall_output_count(stall_output_count)
    );

    task automatic run_vector(
        input logic [255:0] seed_value,
        input logic [255:0] expected_public
    );
        int cycles;
        begin
            seed <= seed_value;
            seed_valid <= 1'b1;
            while (!seed_ready) @(posedge clk);
            @(posedge clk);
            seed_valid <= 1'b0;

            cycles = 0;
            while (!out_valid && cycles < 2_000_000) begin
                @(posedge clk);
                cycles++;
            end

            if (!out_valid)
                $fatal(1, "timeout waiting for HT stream output");
            if (out_seed !== seed_value)
                $fatal(1, "seed mismatch got=%064x expected=%064x", out_seed, seed_value);
            if (out_public_key !== expected_public)
                $fatal(1, "public mismatch got=%064x expected=%064x", out_public_key, expected_public);

            @(posedge clk);
            $display("PASS ht seed=%064x public=%064x wait_cycles=%0d", out_seed, out_public_key, cycles);
        end
    endtask

    task automatic run_burst;
        logic [255:0] seeds [0:BURST_COUNT-1];
        logic [255:0] expected [0:BURST_COUNT-1];
        int cycles;
        int accept_cycle [0:BURST_COUNT-1];
        int output_cycle [0:BURST_COUNT-1];
        int accepted;
        int produced;
        begin
            seeds[0] = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
            seeds[1] = 256'h607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db1619d;
            expected[0] = 256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103;
            expected[1] = 256'h1a5107f7681a02af2523a6daf372e10e3a0764c9d3fe4bd5b70ab18201985ad7;
            for (int i = 2; i < BURST_COUNT; i++) begin
                seeds[i] = seeds[i - 2];
                expected[i] = expected[i - 2];
            end

            cycles = 0;
            accepted = 0;
            produced = 0;
            seed <= seeds[0];
            seed_valid <= 1'b1;

            while (produced < BURST_COUNT && cycles < 4_000_000) begin
                @(posedge clk);
                cycles++;

                if (seed_valid && seed_ready) begin
                    accept_cycle[accepted] = cycles;
                    accepted++;
                    if (accepted < BURST_COUNT)
                        seed <= seeds[accepted];
                    else
                        seed_valid <= 1'b0;
                end

                if (out_valid) begin
                    if (out_seed !== seeds[produced])
                        $fatal(1, "burst seed mismatch idx=%0d got=%064x expected=%064x", produced, out_seed, seeds[produced]);
                    if (out_public_key !== expected[produced])
                        $fatal(1, "burst public mismatch idx=%0d got=%064x expected=%064x", produced, out_public_key, expected[produced]);
                    output_cycle[produced] = cycles;
                    produced++;
                end
            end

            if (produced != BURST_COUNT)
                $fatal(1, "timeout waiting for burst outputs accepted=%0d produced=%0d", accepted, produced);
            if (!(accept_cycle[1] < output_cycle[0]))
                $fatal(1, "stream did not overlap second accept=%0d first output=%0d", accept_cycle[1], output_cycle[0]);

            $display("PASS ht burst accept_gap=%0d avg_accept_gap=%0d first_latency=%0d output_gap=%0d avg_output_gap=%0d total=%0d avg_total_gap=%0d",
                     accept_cycle[1] - accept_cycle[0],
                     (accept_cycle[BURST_COUNT-1] - accept_cycle[0]) / (BURST_COUNT-1),
                     output_cycle[0] - accept_cycle[0],
                     output_cycle[1] - output_cycle[0], (output_cycle[BURST_COUNT-1] - output_cycle[0]) / (BURST_COUNT-1), cycles,
                     (output_cycle[BURST_COUNT-1] - accept_cycle[0]) / BURST_COUNT);
        end
    endtask

    initial begin
        seed_valid = 1'b0;
        seed = 256'd0;
        out_ready = 1'b1;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        run_burst();
        @(posedge clk);

        if (accepted_count !== BURST_COUNT)
            $fatal(1, "accepted_count mismatch got=%0d", accepted_count);
        if (produced_count !== BURST_COUNT)
            $fatal(1, "produced_count mismatch got=%0d", produced_count);

        $display("PASS tb_ed25519_ht_keygen_stream");
        $finish;
    end
endmodule
