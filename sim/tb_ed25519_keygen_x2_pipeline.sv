`timescale 1ns / 1ps

module tb_ed25519_keygen_x2_pipeline;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic seed_valid = 1'b0;
    logic seed_ready;
    logic [255:0] seed = 256'd0;
    logic busy;
    logic candidate_valid;
    logic candidate_ready = 1'b1;
    logic [255:0] candidate_seed;
    logic [255:0] candidate_public_key;

    localparam logic [255:0] SEED0 = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
    localparam logic [255:0] PUB0  = 256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103;
    localparam logic [255:0] SEED1 = 256'h607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db1619d;
    localparam logic [255:0] PUB1  = 256'h1a5107f7681a02af2523a6daf372e10e3a0764c9d3fe4bd5b70ab18201985ad7;

    logic [255:0] got_seed0;
    logic [255:0] got_public0;
    logic [255:0] got_seed1;
    logic [255:0] got_public1;

    ed25519_keygen_x2_pipeline dut (
        .clk(clk),
        .rst_n(rst_n),
        .seed_valid(seed_valid),
        .seed_ready(seed_ready),
        .seed(seed),
        .busy(busy),
        .candidate_valid(candidate_valid),
        .candidate_ready(candidate_ready),
        .candidate_seed(candidate_seed),
        .candidate_public_key(candidate_public_key)
    );

    always #10 clk = ~clk;

    task automatic send_seed(input logic [255:0] value);
        begin
            seed <= value;
            seed_valid <= 1'b1;
            do @(posedge clk); while (!seed_ready);
            @(posedge clk);
            seed_valid <= 1'b0;
        end
    endtask

    task automatic expect_candidate(
        output logic [255:0] out_seed,
        output logic [255:0] out_public
    );
        int cycles;
        begin
            cycles = 0;
            while (!candidate_valid && cycles < 2_000_000) begin
                @(posedge clk);
                cycles++;
            end
            if (!candidate_valid)
                $fatal(1, "timeout waiting for candidate");
            out_seed = candidate_seed;
            out_public = candidate_public_key;
            $display("candidate seed=%064x public=%064x wait_cycles=%0d", out_seed, out_public, cycles);
            @(posedge clk);
        end
    endtask

    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        send_seed(SEED0);
        send_seed(SEED1);

        expect_candidate(got_seed0, got_public0);
        expect_candidate(got_seed1, got_public1);

        if (!((got_seed0 == SEED0 && got_public0 == PUB0) || (got_seed1 == SEED0 && got_public1 == PUB0)))
            $fatal(1, "missing SEED0/PUB0 got0 seed=%064x pub=%064x got1 seed=%064x pub=%064x",
                   got_seed0, got_public0, got_seed1, got_public1);
        if (!((got_seed0 == SEED1 && got_public0 == PUB1) || (got_seed1 == SEED1 && got_public1 == PUB1)))
            $fatal(1, "missing SEED1/PUB1 got0 seed=%064x pub=%064x got1 seed=%064x pub=%064x",
                   got_seed0, got_public0, got_seed1, got_public1);

        $display("PASS tb_ed25519_keygen_x2_pipeline");
        $finish;
    end
endmodule
