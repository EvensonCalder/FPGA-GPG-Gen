`timescale 1ns / 1ps

module tb_ed25519_ht_keygen_core #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic start;
    logic busy;
    logic done;
    logic [255:0] seed;
    logic [255:0] seed_out;
    logic [511:0] expanded_secret;
    logic [255:0] public_key;

    ed25519_ht_keygen_core #(
        .INIT_FILE(INIT_FILE)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .seed(seed),
        .busy(busy), .done(done), .seed_out(seed_out),
        .expanded_secret(expanded_secret), .public_key(public_key)
    );

    task automatic run_vector(input logic [255:0] seed_value, input logic [255:0] expected_public);
        int cycles;
        begin
            seed = seed_value;
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            cycles = 0;
            while (!done && cycles < 200000) begin
                @(posedge clk);
                cycles++;
            end
            if (!done)
                $fatal(1, "timeout waiting for HT keygen done");
            #1;
            if (seed_out !== seed_value)
                $fatal(1, "seed mismatch got=%064x expected=%064x", seed_out, seed_value);
            if (public_key !== expected_public)
                $fatal(1, "public mismatch got=%064x expected=%064x cycles=%0d", public_key, expected_public, cycles);
            $display("PASS ht keygen seed=%064x public=%064x cycles=%0d", seed_out, public_key, cycles);
            repeat (5) @(posedge clk);
        end
    endtask

    initial begin
        start = 1'b0;
        seed = 256'd0;
        repeat (5) @(posedge clk);
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

        $display("PASS tb_ed25519_ht_keygen_core");
        $finish;
    end
endmodule
