`timescale 1ns / 1ps

module gpg_vanity_filter #(
    parameter DEBUG_ACCEPT_ALL = 1'b0,
    parameter MATCH_SUFFIX = 1'b1,
    parameter MATCH_PREFIX = 1'b1
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [31:0]  timestamp,
    input  logic         candidate_valid,
    output logic         candidate_ready,
    input  logic [255:0] seed,
    input  logic [255:0] public_key,
    output logic         hit_valid,
    output logic [3:0]   hit_class_id,
    output logic [255:0] hit_seed,
    output logic [255:0] hit_public_key,
    output logic [159:0] hit_fingerprint
);
    logic fp_start;
    logic fp_busy;
    logic fp_done;
    logic [159:0] fingerprint;
    logic match_hit;
    logic [3:0] match_class_id;

    logic [255:0] seed_reg;
    logic [255:0] public_key_reg;

    assign candidate_ready = !fp_busy && !fp_done;
    assign fp_start = candidate_valid && candidate_ready;

    openpgp_v4_ed25519_fingerprint u_fingerprint (
        .clk(clk),
        .rst_n(rst_n),
        .start(fp_start),
        .timestamp(timestamp),
        .public_key(public_key),
        .busy(fp_busy),
        .done(fp_done),
        .fingerprint(fingerprint)
    );

    gpg_vanity_pattern_matcher #(
        .DEBUG_ACCEPT_ALL(DEBUG_ACCEPT_ALL),
        .MATCH_SUFFIX(MATCH_SUFFIX),
        .MATCH_PREFIX(MATCH_PREFIX)
    ) u_matcher (
        .fingerprint(fingerprint),
        .hit(match_hit),
        .class_id(match_class_id)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seed_reg <= 256'd0;
            public_key_reg <= 256'd0;
            hit_valid <= 1'b0;
            hit_class_id <= 4'd0;
            hit_seed <= 256'd0;
            hit_public_key <= 256'd0;
            hit_fingerprint <= 160'd0;
        end else begin
            hit_valid <= 1'b0;

            if (fp_start) begin
                seed_reg <= seed;
                public_key_reg <= public_key;
            end

            if (fp_done && match_hit) begin
                hit_valid <= 1'b1;
                hit_class_id <= match_class_id;
                hit_seed <= seed_reg;
                hit_public_key <= public_key_reg;
                hit_fingerprint <= fingerprint;
            end
        end
    end
endmodule
