`timescale 1ns / 1ps

module gpg_vanity_search_top #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 2000000,
    parameter logic [31:0] TIMESTAMP = 32'd1700000000
) (
    input  logic clk_50m,
    input  logic key2_reset_n,
    output logic uart_tx
);
    typedef enum logic [1:0] {
        ST_FILL_SEED,
        ST_START_KEYGEN,
        ST_WAIT_KEYGEN,
        ST_SEND_CANDIDATE
    } state_t;

    state_t state;

    logic [7:0] trng_byte;
    logic trng_valid;
    logic trng_ready;
    logic trng_health_fail;
    logic trng_startup_done;

    logic [255:0] seed_shift;
    logic [5:0] seed_byte_count;
    logic [255:0] keygen_seed;
    logic keygen_start;
    logic keygen_busy;
    logic keygen_done;
    logic [255:0] keygen_seed_out;
    logic [511:0] keygen_expanded_secret;
    logic [255:0] keygen_public_key;

    logic backend_candidate_valid;
    logic backend_candidate_ready;

    assign trng_ready = (state == ST_FILL_SEED) && trng_startup_done && !trng_health_fail;

    trng_core #(
        .RO_COUNT(32),
        .STARTUP_SAMPLES(65536),
        .RCT_CUTOFF(64),
        .APT_WINDOW(512),
        .APT_LOW(160),
        .APT_HIGH(352),
        .SAMPLE_DIV(8),
        .CONDITIONER_BITS(32)
    ) u_trng (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .random_ready(trng_ready),
        .random_byte(trng_byte),
        .random_valid(trng_valid),
        .health_fail(trng_health_fail),
        .startup_done(trng_startup_done),
        .raw_bit()
    );

    ed25519_keygen_core u_keygen (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .start(keygen_start),
        .seed(keygen_seed),
        .busy(keygen_busy),
        .done(keygen_done),
        .seed_out(keygen_seed_out),
        .expanded_secret(keygen_expanded_secret),
        .public_key(keygen_public_key)
    );

    gpg_vanity_backend_uart #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_backend (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .timestamp(TIMESTAMP),
        .candidate_valid(backend_candidate_valid),
        .candidate_ready(backend_candidate_ready),
        .candidate_seed(keygen_seed_out),
        .candidate_public_key(keygen_public_key),
        .uart_tx(uart_tx)
    );

    always_ff @(posedge clk_50m or negedge key2_reset_n) begin
        if (!key2_reset_n) begin
            state <= ST_FILL_SEED;
            seed_shift <= 256'd0;
            seed_byte_count <= 6'd0;
            keygen_seed <= 256'd0;
            keygen_start <= 1'b0;
            backend_candidate_valid <= 1'b0;
        end else begin
            keygen_start <= 1'b0;
            backend_candidate_valid <= 1'b0;

            case (state)
                ST_FILL_SEED: begin
                    if (trng_valid && trng_ready) begin
                        seed_shift <= {trng_byte, seed_shift[255:8]};
                        if (seed_byte_count == 6'd31) begin
                            keygen_seed <= {trng_byte, seed_shift[255:8]};
                            seed_byte_count <= 6'd0;
                            state <= ST_START_KEYGEN;
                        end else begin
                            seed_byte_count <= seed_byte_count + 1'b1;
                        end
                    end
                end

                ST_START_KEYGEN: begin
                    keygen_start <= 1'b1;
                    state <= ST_WAIT_KEYGEN;
                end

                ST_WAIT_KEYGEN: begin
                    if (keygen_done)
                        state <= ST_SEND_CANDIDATE;
                end

                ST_SEND_CANDIDATE: begin
                    if (backend_candidate_ready) begin
                        backend_candidate_valid <= 1'b1;
                        state <= ST_FILL_SEED;
                    end
                end

                default: begin
                    state <= ST_FILL_SEED;
                end
            endcase
        end
    end
endmodule
