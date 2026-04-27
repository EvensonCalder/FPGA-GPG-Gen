`timescale 1ns / 1ps

module tb_ed25519_keygen_core;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [255:0] seed = 256'd0;
    logic busy;
    logic done;
    logic [255:0] seed_out;
    logic [511:0] expanded_secret;
    logic [255:0] public_key;

    ed25519_keygen_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .seed(seed),
        .busy(busy),
        .done(done),
        .seed_out(seed_out),
        .expanded_secret(expanded_secret),
        .public_key(public_key)
    );

    always #10 clk = ~clk;

    task automatic run_vector(
        input logic [255:0] seed_value,
        input logic [255:0] expected_public
    );
        int cycles;
        begin
            seed = seed_value;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            cycles = 0;
            while (!done && cycles < 2_000_000) begin
                @(posedge clk);
                cycles++;
            end

            if (!done) begin
                $fatal(1, "timeout waiting for keygen done");
            end
            if (seed_out !== seed_value) begin
                $fatal(1, "seed_out mismatch: got %064x expected %064x", seed_out, seed_value);
            end
            if (public_key !== expected_public) begin
                $fatal(1, "public_key mismatch: got %064x expected %064x", public_key, expected_public);
            end

            $display("PASS vector seed=%064x public=%064x scalar=%064x ge_x=%080x ge_y=%080x ge_z=%080x ge_t=%080x cycles=%0d",
                     seed_value, public_key, expanded_secret[255:0], dut.ge_x, dut.ge_y, dut.ge_z, dut.ge_t, cycles);
            @(posedge clk);
        end
    endtask

    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        run_vector(
            256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100,
            256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103
        );

        run_vector(
            256'h607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db1619d,
            256'h1a5107f7681a02af2523a6daf372e10e3a0764c9d3fe4bd5b70ab18201985ad7
        );

        $display("PASS tb_ed25519_keygen_core");
        $finish;
    end
endmodule
