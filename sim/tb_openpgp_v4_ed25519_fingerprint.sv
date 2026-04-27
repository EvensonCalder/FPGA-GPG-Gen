`timescale 1ns / 1ps

module tb_openpgp_v4_ed25519_fingerprint;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [31:0] timestamp;
    logic [255:0] public_key;
    logic busy;
    logic done;
    logic [159:0] fingerprint;

    localparam logic [159:0] EXPECTED_FP = 160'h0550f45f55746ceca3e8ae97f7a32568e2019652;

    always #10 clk = ~clk;

    openpgp_v4_ed25519_fingerprint dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .timestamp(timestamp),
        .public_key(public_key),
        .busy(busy),
        .done(done),
        .fingerprint(fingerprint)
    );

    initial begin
        timestamp = 32'd1700000000;
        // Bytes are stored little-endian in the vector: byte 0 is public_key[7:0].
        public_key = 256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (done);
        if (fingerprint !== EXPECTED_FP) begin
            $display("fingerprint mismatch");
            $display("expected=%h", EXPECTED_FP);
            $display("actual  =%h", fingerprint);
            $fatal(1);
        end

        $display("fingerprint ok: %h", fingerprint);
        $finish;
    end
endmodule
