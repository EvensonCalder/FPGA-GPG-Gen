`timescale 1ns / 1ps

module tb_gpg_vanity_keygen_fingerprint_matcher #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
);
    localparam logic [255:0] SEED0 = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
    localparam logic [255:0] PUBLIC0 = 256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103;
    localparam logic [159:0] FP0 = 160'h0550f45f55746ceca3e8ae97f7a32568e2019652;

    localparam logic [255:0] BAD_PUBLIC = 256'h525588c7027e35cdbcb861923f66478a026773d65c7532cd5f63407f5d2fd643;
    localparam logic [159:0] BAD_FP = 160'hb9aa51839968da86017ed4b69911a7b5bba59f1f;

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

    logic fp_start;
    logic fp_busy;
    logic fp_done;
    logic [255:0] fp_public;
    logic [159:0] fingerprint;
    logic match_hit;
    logic [3:0] match_class_id;

    ed25519_ht_keygen_stream #(
        .INIT_FILE(INIT_FILE),
        .LANES(1),
        .MUL_LANES(1),
        .NATIVE_COMPRESS(1'b0),
        .BATCH_COMPRESS(1'b0),
        .MULTI_CONTEXT_SCALAR(1'b0)
    ) u_keygen (
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

    openpgp_v4_ed25519_fingerprint u_fp (
        .clk(clk),
        .rst_n(rst_n),
        .start(fp_start),
        .timestamp(32'd1700000000),
        .public_key(fp_public),
        .busy(fp_busy),
        .done(fp_done),
        .fingerprint(fingerprint)
    );

    gpg_vanity_pattern_matcher u_matcher (
        .fingerprint(fingerprint),
        .hit(match_hit),
        .class_id(match_class_id)
    );

    task automatic run_fingerprint_check(
        input logic [255:0] public_key,
        input logic [159:0] expected_fp,
        input logic expected_hit,
        input logic [3:0] expected_class
    );
        begin
            fp_public <= public_key;
            fp_start <= 1'b1;
            @(posedge clk);
            fp_start <= 1'b0;
            wait (fp_done);
            #1;
            if (fingerprint !== expected_fp)
                $fatal(1, "fingerprint mismatch got=%040x expected=%040x", fingerprint, expected_fp);
            if (match_hit !== expected_hit || (expected_hit && match_class_id !== expected_class))
                $fatal(1, "matcher mismatch fp=%040x hit=%0d class=%0h expected_hit=%0d expected_class=%0h",
                       fingerprint, match_hit, match_class_id, expected_hit, expected_class);
            @(posedge clk);
        end
    endtask

    initial begin
        seed_valid = 1'b0;
        seed = 256'd0;
        out_ready = 1'b1;
        fp_start = 1'b0;
        fp_public = 256'd0;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        seed <= SEED0;
        seed_valid <= 1'b1;
        while (!seed_ready) @(posedge clk);
        @(posedge clk);
        seed_valid <= 1'b0;

        wait (out_valid);
        if (out_seed !== SEED0)
            $fatal(1, "keygen seed mismatch got=%064x expected=%064x", out_seed, SEED0);
        if (out_public_key !== PUBLIC0)
            $fatal(1, "keygen public mismatch got=%064x expected=%064x", out_public_key, PUBLIC0);

        run_fingerprint_check(out_public_key, FP0, 1'b0, 4'h0);
        run_fingerprint_check(BAD_PUBLIC, BAD_FP, 1'b0, 4'h0);

        $display("PASS tb_gpg_vanity_keygen_fingerprint_matcher");
        $finish;
    end

    initial begin
        repeat (3_000_000) @(posedge clk);
        $fatal(1, "timeout waiting for keygen/fingerprint checks");
    end
endmodule
