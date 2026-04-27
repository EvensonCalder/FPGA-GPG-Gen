`timescale 1ns / 1ps

module gpg_vanity_search_hf_top #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 2000000,
    parameter logic [31:0] TIMESTAMP = 32'd1700000000,
    parameter DEBUG_ACCEPT_ALL = 1'b0
) (
    input  logic clk_50m,
    input  logic key2_reset_n,
    output logic uart_tx
);
    logic sys_clk;
    logic sys_rst_n;
    logic       pll_locked;
    logic       sys_fb;

    logic [7:0] trng_byte;
    logic trng_valid;
    logic trng_ready;
    logic trng_health_fail;
    logic trng_startup_done;

    logic [255:0] seed_buf;
    logic [5:0] seed_byte_count;
    logic       seed_full;
    logic       seed_req;
    logic       seed_req_toggle;
    logic       seed_ack_toggle;
    logic       seed_ack_sync0, seed_ack_sync1, seed_ack_seen;

    logic       kg_start;
    logic       kg_busy;
    logic       kg_done;
    logic [255:0] kg_seed;
    logic [255:0] kg_seed_out;
    logic [255:0] kg_public;
    logic [255:0] result_seed;
    logic [255:0] result_public;
    logic [255:0] backend_seed;
    logic [255:0] backend_public;

    logic       backend_valid;
    logic       backend_ready;
    logic       result_toggle;
    logic       result_toggle_sync0, result_toggle_sync1, result_seen;
    logic       result_ack_toggle;
    logic       result_ack_sync0, result_ack_sync1;

    assign trng_ready = trng_startup_done && !trng_health_fail;
    assign seed_req = !seed_full;

    PLLE2_BASE #(
        .CLKFBOUT_MULT(24),
        .CLKIN1_PERIOD(20.0),
        .CLKOUT0_DIVIDE(16),
        .DIVCLK_DIVIDE(1)
    ) u_pll (
        .CLKIN1(clk_50m),
        .CLKOUT0(sys_clk),
        .LOCKED(pll_locked),
        .PWRDWN(1'b0),
        .RST(~key2_reset_n),
        .CLKFBOUT(sys_fb),
        .CLKFBIN(sys_fb),
        .CLKOUT1(), .CLKOUT2(), .CLKOUT3(), .CLKOUT4(), .CLKOUT5()
    );

    assign sys_rst_n = key2_reset_n && pll_locked;

    trng_core #(
        .RO_COUNT(32), .STARTUP_SAMPLES(65536),
        .RCT_CUTOFF(64), .APT_WINDOW(512),
        .APT_LOW(160), .APT_HIGH(352),
        .SAMPLE_DIV(8), .CONDITIONER_BITS(32)
    ) u_trng (
        .clk(clk_50m), .rst_n(key2_reset_n),
        .random_ready(trng_ready), .random_byte(trng_byte),
        .random_valid(trng_valid), .health_fail(trng_health_fail),
        .startup_done(trng_startup_done), .raw_bit()
    );

    ed25519_keygen_core u_keygen (
        .clk(sys_clk), .rst_n(sys_rst_n),
        .start(kg_start), .seed(kg_seed),
        .busy(kg_busy), .done(kg_done),
        .seed_out(kg_seed_out), .expanded_secret(),
        .public_key(kg_public)
    );

    logic seed_req_sync0, seed_req_sync1, seed_req_seen;
    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            seed_req_sync0 <= 1'b0;
            seed_req_sync1 <= 1'b0;
            seed_req_seen <= 1'b0;
            seed_ack_toggle <= 1'b0;
            result_toggle <= 1'b0;
            result_ack_sync0 <= 1'b0;
            result_ack_sync1 <= 1'b0;
            kg_start <= 1'b0;
            kg_seed <= 256'd0;
            result_seed <= 256'd0;
            result_public <= 256'd0;
        end else begin
            seed_req_sync0 <= seed_req_toggle;
            seed_req_sync1 <= seed_req_sync0;
            result_ack_sync0 <= result_ack_toggle;
            result_ack_sync1 <= result_ack_sync0;
            kg_start <= 1'b0;

            if ((seed_req_sync1 != seed_req_seen) && !kg_busy && (result_toggle == result_ack_sync1)) begin
                seed_req_seen <= seed_req_sync1;
                kg_seed <= seed_buf;
                kg_start <= 1'b1;
                seed_ack_toggle <= ~seed_ack_toggle;
            end

            if (kg_done) begin
                result_seed <= kg_seed_out;
                result_public <= kg_public;
                result_toggle <= ~result_toggle;
            end
        end
    end

    always_ff @(posedge clk_50m or negedge key2_reset_n) begin
        if (!key2_reset_n) begin
            seed_buf <= 256'd0; seed_byte_count <= 6'd0;
            seed_full <= 1'b0;
            seed_req_toggle <= 1'b0;
            seed_ack_sync0 <= 1'b0;
            seed_ack_sync1 <= 1'b0;
            seed_ack_seen <= 1'b0;
            result_toggle_sync0 <= 1'b0;
            result_toggle_sync1 <= 1'b0;
            result_seen <= 1'b0;
            result_ack_toggle <= 1'b0;
            backend_seed <= 256'd0;
            backend_public <= 256'd0;
            backend_valid <= 1'b0;
        end else begin
            seed_ack_sync0 <= seed_ack_toggle;
            seed_ack_sync1 <= seed_ack_sync0;
            result_toggle_sync0 <= result_toggle;
            result_toggle_sync1 <= result_toggle_sync0;

            if (trng_valid && trng_ready && seed_req) begin
                seed_buf <= {trng_byte, seed_buf[255:8]};
                if (seed_byte_count == 6'd31) begin
                    seed_full <= 1'b1;
                    seed_req_toggle <= ~seed_req_toggle;
                    seed_byte_count <= 6'd0;
                end else begin
                    seed_byte_count <= seed_byte_count + 1'b1;
                end
            end

            if (seed_full && (seed_ack_sync1 != seed_ack_seen)) begin
                seed_ack_seen <= seed_ack_sync1;
                seed_full <= 1'b0;
            end

            backend_valid <= 1'b0;
            if (result_toggle_sync1 != result_seen) begin
                result_seen <= result_toggle_sync1;
                backend_seed <= result_seed;
                backend_public <= result_public;
                result_ack_toggle <= ~result_ack_toggle;
                backend_valid <= 1'b1;
            end
        end
    end

    gpg_vanity_backend_uart #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD),
        .DEBUG_ACCEPT_ALL(DEBUG_ACCEPT_ALL)
    ) u_backend (
        .clk(clk_50m), .rst_n(key2_reset_n),
        .timestamp(TIMESTAMP),
        .candidate_valid(backend_valid), .candidate_ready(backend_ready),
        .candidate_seed(backend_seed), .candidate_public_key(backend_public),
        .uart_tx(uart_tx)
    );
endmodule
