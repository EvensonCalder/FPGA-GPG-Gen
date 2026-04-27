`timescale 1ns / 1ps

module tb_dual_keygen;
    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic       start0 = 1'b0;
    logic       done0;
    logic [255:0] seed0;
    logic [255:0] seed_out0;
    logic [255:0] public0;
    logic       start1 = 1'b0;
    logic       done1;
    logic [255:0] seed1;
    logic [255:0] seed_out1;
    logic [255:0] public1;

    localparam logic [255:0] SEED0 = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
    localparam logic [255:0] PUB0  = 256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103;
    localparam logic [255:0] SEED1 = 256'h607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db1619d;
    localparam logic [255:0] PUB1  = 256'h1a5107f7681a02af2523a6daf372e10e3a0764c9d3fe4bd5b70ab18201985ad7;

    ed25519_keygen_core   u0 (
        .clk(clk), .rst_n(rst_n),
        .start(start0), .seed(seed0),
        .busy(), .done(done0),
        .seed_out(seed_out0), .expanded_secret(), .public_key(public0)
    );

    ed25519_keygen_core_b u1 (
        .clk(clk), .rst_n(rst_n),
        .start(start1), .seed(seed1),
        .busy(), .done(done1),
        .seed_out(seed_out1), .expanded_secret(), .public_key(public1)
    );

    always #10 clk = ~clk;

    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        seed0 = SEED0;
        start0 = 1'b1;
        @(posedge clk);
        start0 = 1'b0;

        fork
            begin
                int cycles;
                cycles = 0;
                while (!done0 && cycles < 2000000) begin @(posedge clk); cycles++; end
                if (!done0) $fatal(1, "u0 timeout");
                if (seed_out0 !== SEED0) $fatal(1, "u0 seed mismatch");
                if (public0 !== PUB0) $fatal(1, "u0 public mismatch got %064x expected %064x", public0, PUB0);
                $display("u0 PASS seed=%064x public=%064x cycles=%0d", seed_out0, public0, cycles);
            end
            begin
                int cycles;
                cycles = 0;
                while (!done1 && cycles < 2000000) begin @(posedge clk); cycles++; end
                if (!done1) $fatal(1, "u1 timeout");
                if (seed_out1 !== SEED1) $fatal(1, "u1 seed mismatch");
                if (public1 !== PUB1) $fatal(1, "u1 public mismatch got %064x expected %064x", public1, PUB1);
                $display("u1 PASS seed=%064x public=%064x cycles=%0d", seed_out1, public1, cycles);
            end
        join

        $display("PASS tb_dual_keygen");
        $finish;
    end
endmodule
