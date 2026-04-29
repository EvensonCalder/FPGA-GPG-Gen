`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_scalar_stage #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1
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
    typedef enum logic [2:0] {
        S_IDLE,
        S_HASH,
        S_GE_START,
        S_GE_WAIT,
        S_COMMIT
    } state_t;

    state_t state, prev_state;

    logic [255:0] scalar_seed;
    logic [511:0] hash_out;
    logic [511:0] clamped_secret;
    logic hash_done;
    logic ge_done;
    logic start_hash;
    logic start_ge;
    fe17_t ge_x, ge_y, ge_z, ge_t;

    assign seed_ready = (state == S_IDLE) && (!point_valid || point_ready);
    assign start_hash = (state == S_HASH) && (prev_state != S_HASH);
    assign start_ge = state == S_GE_START;

    SHA512_wrapper_mux u_sha512_wrapper (
        .clk(clk), .rst(rst_n), .start_sha512(start_hash),
        .sha512_mode(2'b00), .hash_message_in(512'd0), .random_number(scalar_seed),
        .hash_pubkey_in(256'd0), .R(256'd0), .seckey32_in(256'd0),
        .end_sha512(hash_done), .hash(hash_out)
    );

    seckey_clamp u_seckey_clamp (
        .input_hashed_seckey(hash_out),
        .output_sk(clamped_secret)
    );

    ed25519_ht_fixedbase_fe17_core #(
        .INIT_FILE(INIT_FILE),
        .MUL_LANES(MUL_LANES)
    ) u_fixedbase_core (
        .clk(clk), .rst_n(rst_n), .start(start_ge),
        .scalar(clamped_secret[255:0]),
        .r_X(ge_x), .r_Y(ge_y), .r_Z(ge_z), .r_T(ge_t),
        .done(ge_done)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            prev_state <= S_IDLE;
            scalar_seed <= 256'd0;
            point_valid <= 1'b0;
            point_seed <= 256'd0;
            point_x <= '0;
            point_y <= '0;
            point_z <= '0;
        end else begin
            prev_state <= state;

            if (point_valid && point_ready)
                point_valid <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    if (seed_valid && seed_ready) begin
                        scalar_seed <= seed;
                        state <= S_HASH;
                    end
                end
                S_HASH: begin
                    if (hash_done)
                        state <= S_GE_START;
                end
                S_GE_START: state <= S_GE_WAIT;
                S_GE_WAIT: begin
                    if (ge_done)
                        state <= S_COMMIT;
                end
                S_COMMIT: begin
                    if (!point_valid || point_ready) begin
                        point_seed <= scalar_seed;
                        point_x <= ge_x;
                        point_y <= ge_y;
                        point_z <= ge_z;
                        point_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
