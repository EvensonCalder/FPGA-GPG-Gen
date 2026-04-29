`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_scalar_mc_stage #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer CONTEXTS = 16,
    parameter integer MUL_LANES = 2
) (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         seed_valid,
    output logic         seed_ready,
    input  logic [255:0] seed,

    output logic         point_valid,
    input  logic         point_ready,
    output logic [255:0] point_seed,
    output fe17_t        point_x,
    output fe17_t        point_y,
    output fe17_t        point_z
);
    localparam int CTX_BITS = (CONTEXTS <= 1) ? 1 : $clog2(CONTEXTS);

    typedef enum logic [2:0] {
        CTX_EMPTY,
        CTX_HASH_PENDING,
        CTX_HASH_BUSY,
        CTX_FB_PENDING,
        CTX_FB_BUSY
    } ctx_state_t;

    ctx_state_t ctx_state [0:CONTEXTS-1];
    logic [255:0] ctx_seed [0:CONTEXTS-1];
    logic [255:0] ctx_scalar [0:CONTEXTS-1];
    logic [CTX_BITS-1:0] alloc_ptr, hash_ptr, fb_ptr;
    logic [CTX_BITS-1:0] alloc_idx, hash_idx, fb_idx;
    logic alloc_found, hash_found, fb_found;

    logic start_hash;
    logic hash_unit_busy;
    logic hash_done;
    logic [CTX_BITS-1:0] hash_ctx;
    logic [255:0] hash_seed;
    logic [511:0] hash_out;
    logic [511:0] clamped_secret;

    logic fb_scalar_valid, fb_scalar_ready;
    logic [CTX_BITS-1:0] fb_point_tag;
    logic fb_point_valid, fb_point_ready;
    fe17_t fb_point_x, fb_point_y, fb_point_z;

    function automatic logic [CTX_BITS-1:0] wrap_ctx(input int unsigned value);
        int unsigned v;
        begin
            v = value;
            if (value >= CONTEXTS)
                v = value - CONTEXTS;
            return v[CTX_BITS-1:0];
        end
    endfunction

    always_comb begin
        alloc_found = 1'b0;
        alloc_idx = alloc_ptr;
        for (int n = 0; n < CONTEXTS; n++) begin
            logic [CTX_BITS-1:0] probe;
            probe = wrap_ctx(alloc_ptr + n);
            if (!alloc_found && ctx_state[probe] == CTX_EMPTY) begin
                alloc_found = 1'b1;
                alloc_idx = probe;
            end
        end

        hash_found = 1'b0;
        hash_idx = hash_ptr;
        for (int n = 0; n < CONTEXTS; n++) begin
            logic [CTX_BITS-1:0] probe;
            probe = wrap_ctx(hash_ptr + n);
            if (!hash_found && ctx_state[probe] == CTX_HASH_PENDING) begin
                hash_found = 1'b1;
                hash_idx = probe;
            end
        end

        fb_found = 1'b0;
        fb_idx = fb_ptr;
        for (int n = 0; n < CONTEXTS; n++) begin
            logic [CTX_BITS-1:0] probe;
            probe = wrap_ctx(fb_ptr + n);
            if (!fb_found && ctx_state[probe] == CTX_FB_PENDING) begin
                fb_found = 1'b1;
                fb_idx = probe;
            end
        end
    end

    assign seed_ready = alloc_found;
    assign start_hash = hash_found && !hash_unit_busy;
    assign fb_scalar_valid = fb_found;
    assign fb_point_ready = !point_valid || point_ready;

    SHA512_wrapper_mux u_sha512_wrapper (
        .clk(clk), .rst(rst_n), .start_sha512(start_hash),
        .sha512_mode(2'b00), .hash_message_in(512'd0), .random_number(hash_seed),
        .hash_pubkey_in(256'd0), .R(256'd0), .seckey32_in(256'd0),
        .end_sha512(hash_done), .hash(hash_out)
    );

    seckey_clamp u_seckey_clamp (
        .input_hashed_seckey(hash_out),
        .output_sk(clamped_secret)
    );

    ed25519_ht_fixedbase_sched #(
        .INIT_FILE(INIT_FILE),
        .CONTEXTS(CONTEXTS),
        .TAG_WIDTH(CTX_BITS)
    ) u_fixedbase_sched (
        .clk(clk), .rst_n(rst_n),
        .scalar_valid(fb_scalar_valid), .scalar_ready(fb_scalar_ready),
        .scalar(ctx_scalar[fb_idx]), .scalar_tag(fb_idx),
        .point_valid(fb_point_valid), .point_ready(fb_point_ready),
        .point_tag(fb_point_tag),
        .point_x(fb_point_x), .point_y(fb_point_y), .point_z(fb_point_z)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alloc_ptr <= '0;
            hash_ptr <= '0;
            fb_ptr <= '0;
            hash_ctx <= '0;
            hash_unit_busy <= 1'b0;
            hash_seed <= 256'd0;
            point_valid <= 1'b0;
            point_seed <= 256'd0;
            point_x <= '0;
            point_y <= '0;
            point_z <= '0;
            for (int i = 0; i < CONTEXTS; i++) begin
                ctx_state[i] <= CTX_EMPTY;
                ctx_seed[i] <= 256'd0;
                ctx_scalar[i] <= 256'd0;
            end
        end else begin
            if (point_valid && point_ready)
                point_valid <= 1'b0;

            if (seed_valid && seed_ready) begin
                ctx_seed[alloc_idx] <= seed;
                ctx_state[alloc_idx] <= CTX_HASH_PENDING;
                alloc_ptr <= wrap_ctx(alloc_idx + 1);
            end

            if (start_hash) begin
                hash_ctx <= hash_idx;
                hash_seed <= ctx_seed[hash_idx];
                hash_unit_busy <= 1'b1;
                ctx_state[hash_idx] <= CTX_HASH_BUSY;
                hash_ptr <= wrap_ctx(hash_idx + 1);
            end

            if (hash_done) begin
                hash_unit_busy <= 1'b0;
                ctx_scalar[hash_ctx] <= clamped_secret[255:0];
                ctx_state[hash_ctx] <= CTX_FB_PENDING;
            end

            if (fb_scalar_valid && fb_scalar_ready) begin
                ctx_state[fb_idx] <= CTX_FB_BUSY;
                fb_ptr <= wrap_ctx(fb_idx + 1);
            end

            if (fb_point_valid && fb_point_ready) begin
                point_valid <= 1'b1;
                point_seed <= ctx_seed[fb_point_tag];
                point_x <= fb_point_x;
                point_y <= fb_point_y;
                point_z <= fb_point_z;
                ctx_state[fb_point_tag] <= CTX_EMPTY;
            end
        end
    end
endmodule
