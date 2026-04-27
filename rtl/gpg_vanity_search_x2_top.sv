`timescale 1ns / 1ps

module gpg_vanity_search_x2_top #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 2000000,
    parameter logic [31:0] TIMESTAMP = 32'd1700000000
) (
    input  logic clk_50m,
    input  logic key2_reset_n,
    output logic uart_tx
);
    logic [7:0] trng_byte;
    logic trng_valid;
    logic trng_ready;
    logic trng_health_fail;
    logic trng_startup_done;

    logic [255:0] seed_shift;
    logic [5:0] seed_byte_count;
    logic       pipeline_seed_valid;
    logic       pipeline_seed_ready;
    logic [255:0] pipeline_seed;
    logic       pipeline_busy;
    logic       pipeline_candidate_valid;
    logic       pipeline_candidate_ready;
    logic [255:0] pipeline_candidate_seed;
    logic [255:0] pipeline_candidate_public_key;

    typedef enum logic [1:0] {
        ST_FILL_SEED,
        ST_WAIT_SEED,
        ST_IDLE
    } state_t;
    state_t state;

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

    ed25519_keygen_x2_pipeline u_pipeline (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .seed_valid(pipeline_seed_valid),
        .seed_ready(pipeline_seed_ready),
        .seed(pipeline_seed),
        .busy(pipeline_busy),
        .candidate_valid(pipeline_candidate_valid),
        .candidate_ready(pipeline_candidate_ready),
        .candidate_seed(pipeline_candidate_seed),
        .candidate_public_key(pipeline_candidate_public_key)
    );

    gpg_vanity_backend_uart #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_backend (
        .clk(clk_50m),
        .rst_n(key2_reset_n),
        .timestamp(TIMESTAMP),
        .candidate_valid(pipeline_candidate_valid),
        .candidate_ready(pipeline_candidate_ready),
        .candidate_seed(pipeline_candidate_seed),
        .candidate_public_key(pipeline_candidate_public_key),
        .uart_tx(uart_tx)
    );

    always_ff @(posedge clk_50m or negedge key2_reset_n) begin
        if (!key2_reset_n) begin
            state <= ST_FILL_SEED;
            seed_shift <= 256'd0;
            seed_byte_count <= 6'd0;
            pipeline_seed <= 256'd0;
            pipeline_seed_valid <= 1'b0;
        end else begin
            pipeline_seed_valid <= 1'b0;

            case (state)
                ST_FILL_SEED: begin
                    if (trng_valid && trng_ready) begin
                        seed_shift <= {trng_byte, seed_shift[255:8]};
                        if (seed_byte_count == 6'd31) begin
                            pipeline_seed <= {trng_byte, seed_shift[255:8]};
                            seed_byte_count <= 6'd0;
                            state <= ST_WAIT_SEED;
                        end else begin
                            seed_byte_count <= seed_byte_count + 1'b1;
                        end
                    end
                end

                ST_WAIT_SEED: begin
                    if (pipeline_seed_ready) begin
                        pipeline_seed_valid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_IDLE: begin
                    state <= ST_FILL_SEED;
                end

                default: state <= ST_FILL_SEED;
            endcase
        end
    end
endmodule
