`timescale 1ns / 1ps

module gpg_vanity_ht_search_top #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 2000000,
    parameter logic [31:0] TIMESTAMP = 32'd1700000000,
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer LANES = 1,
    parameter integer MUL_LANES = 1,
    parameter bit NATIVE_COMPRESS = 1'b0,
    parameter bit BATCH_COMPRESS = 1'b0,
    parameter integer BATCH_SIZE = 8,
    parameter bit MULTI_CONTEXT_SCALAR = 1'b0,
    parameter integer SCALAR_CONTEXTS = 8,
    parameter integer TRNG_CORES = 1,
    parameter bit USE_PLL = 1'b0,
    parameter DEBUG_ACCEPT_ALL = 1'b0,
    parameter bit SIM_SEED_MODE = 1'b0,
    parameter logic [255:0] SIM_SEED_START = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100
) (
    input  logic clk_50m,
    input  logic key2_reset_n,
    output logic uart_tx
);
    localparam int BACKEND_CLK_HZ = USE_PLL ? 64705882 : CLK_HZ;
    localparam int TRNG_IDX_BITS = (TRNG_CORES <= 1) ? 1 : $clog2(TRNG_CORES);

    logic sys_clk;
    logic sys_rst_n;

    logic [7:0] trng_byte [0:TRNG_CORES-1];
    logic [TRNG_CORES-1:0] trng_valid;
    logic [TRNG_CORES-1:0] trng_ready;
    logic [TRNG_CORES-1:0] trng_health_fail;
    logic [TRNG_CORES-1:0] trng_startup_done;
    logic [TRNG_IDX_BITS-1:0] trng_rr_ptr;
    logic [TRNG_IDX_BITS-1:0] trng_sel_idx;
    logic trng_sel_valid;

    logic [255:0] seed_shift;
    logic [5:0] seed_byte_count;
    logic seed_pending;
    logic [255:0] seed_word;
    logic seed_valid;
    logic seed_ready;

    logic out_valid;
    logic out_ready;
    logic [255:0] out_seed;
    logic [255:0] out_public_key;
    logic [63:0] accepted_count;
    logic [63:0] produced_count;
    logic [63:0] stall_seed_count;
    logic [63:0] stall_output_count;

    assign seed_valid = seed_pending;

    generate
        if (USE_PLL) begin : gen_sys_pll
            logic pll_clk;
            logic pll_fb;
            logic pll_fb_buf;
            logic pll_locked;
            logic pll_rst_n;
            logic [1:0] rst_sync;

            PLLE2_BASE #(
                .CLKFBOUT_MULT(22),
                .CLKIN1_PERIOD(20.0),
                .CLKOUT0_DIVIDE(17),
                .DIVCLK_DIVIDE(1)
            ) u_pll (
                .CLKIN1(clk_50m),
                .CLKOUT0(pll_clk),
                .LOCKED(pll_locked),
                .PWRDWN(1'b0),
                .RST(~key2_reset_n),
                .CLKFBOUT(pll_fb),
                .CLKFBIN(pll_fb_buf),
                .CLKOUT1(), .CLKOUT2(), .CLKOUT3(), .CLKOUT4(), .CLKOUT5()
            );

            BUFG u_pll_fb_buf (.I(pll_fb), .O(pll_fb_buf));
            BUFG u_sys_clk_buf (.I(pll_clk), .O(sys_clk));

            assign pll_rst_n = key2_reset_n && pll_locked;

            always_ff @(posedge sys_clk or negedge pll_rst_n) begin
                if (!pll_rst_n)
                    rst_sync <= 2'b00;
                else
                    rst_sync <= {rst_sync[0], 1'b1};
            end

            assign sys_rst_n = rst_sync[1];
        end else begin : gen_sys_clk_direct
            assign sys_clk = clk_50m;
            assign sys_rst_n = key2_reset_n;
        end
    endgenerate

    function automatic logic [TRNG_IDX_BITS-1:0] wrap_trng_idx(input int unsigned value);
        int unsigned v;
        begin
            v = value;
            if (value >= TRNG_CORES)
                v = value - TRNG_CORES;
            return v[TRNG_IDX_BITS-1:0];
        end
    endfunction

    always_comb begin
        trng_sel_valid = 1'b0;
        trng_sel_idx = trng_rr_ptr;
        trng_ready = '0;
        for (int n = 0; n < TRNG_CORES; n++) begin
            logic [TRNG_IDX_BITS-1:0] probe;
            probe = wrap_trng_idx(trng_rr_ptr + n);
            if (!trng_sel_valid && trng_startup_done[probe] && !trng_health_fail[probe] && trng_valid[probe]) begin
                trng_sel_valid = 1'b1;
                trng_sel_idx = probe;
            end
        end
        if (trng_sel_valid && !seed_pending)
            trng_ready[trng_sel_idx] = 1'b1;
    end

    generate
        if (SIM_SEED_MODE) begin : gen_sim_seed
            for (genvar i = 0; i < TRNG_CORES; i++) begin : gen_sim_trng_signals
                assign trng_byte[i] = 8'd0;
                assign trng_valid[i] = 1'b0;
                assign trng_health_fail[i] = 1'b0;
                assign trng_startup_done[i] = 1'b1;
            end

            always_ff @(posedge sys_clk or negedge sys_rst_n) begin
                if (!sys_rst_n) begin
                    seed_shift <= 256'd0;
                    seed_byte_count <= 6'd0;
                    seed_pending <= 1'b0;
                    seed_word <= SIM_SEED_START;
                    trng_rr_ptr <= '0;
                end else begin
                    seed_pending <= 1'b1;
                    if (seed_valid && seed_ready)
                        seed_word <= seed_word + 1'b1;
                end
            end
        end else begin : gen_trng_seed
            for (genvar i = 0; i < TRNG_CORES; i++) begin : gen_trng_core
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
                    .clk(sys_clk),
                    .rst_n(sys_rst_n),
                    .random_ready(trng_ready[i]),
                    .random_byte(trng_byte[i]),
                    .random_valid(trng_valid[i]),
                    .health_fail(trng_health_fail[i]),
                    .startup_done(trng_startup_done[i]),
                    .raw_bit()
                );
            end

            always_ff @(posedge sys_clk or negedge sys_rst_n) begin
                if (!sys_rst_n) begin
                    seed_shift <= 256'd0;
                    seed_byte_count <= 6'd0;
                    seed_pending <= 1'b0;
                    seed_word <= 256'd0;
                    trng_rr_ptr <= '0;
                end else begin
                    if (seed_valid && seed_ready)
                        seed_pending <= 1'b0;

                    if (trng_sel_valid && trng_ready[trng_sel_idx]) begin
                        trng_rr_ptr <= wrap_trng_idx(trng_sel_idx + 1);
                        seed_shift <= {trng_byte[trng_sel_idx], seed_shift[255:8]};
                        if (seed_byte_count == 6'd31) begin
                            seed_word <= {trng_byte[trng_sel_idx], seed_shift[255:8]};
                            seed_byte_count <= 6'd0;
                            seed_pending <= 1'b1;
                        end else begin
                            seed_byte_count <= seed_byte_count + 1'b1;
                        end
                    end
                end
            end
        end
    endgenerate

    ed25519_ht_keygen_stream #(
        .LANES(LANES),
        .INIT_FILE(INIT_FILE),
        .MUL_LANES(MUL_LANES),
        .NATIVE_COMPRESS(NATIVE_COMPRESS),
        .BATCH_COMPRESS(BATCH_COMPRESS),
        .BATCH_SIZE(BATCH_SIZE),
        .MULTI_CONTEXT_SCALAR(MULTI_CONTEXT_SCALAR),
        .SCALAR_CONTEXTS(SCALAR_CONTEXTS)
    ) u_keygen_stream (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .seed_valid(seed_valid),
        .seed_ready(seed_ready),
        .seed(seed_word),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_seed(out_seed),
        .out_public_key(out_public_key),
        .accepted_count(accepted_count),
        .produced_count(produced_count),
        .stall_seed_count(stall_seed_count),
        .stall_output_count(stall_output_count)
    );

    gpg_vanity_backend_uart #(
        .CLK_HZ(BACKEND_CLK_HZ),
        .BAUD(BAUD),
        .DEBUG_ACCEPT_ALL(DEBUG_ACCEPT_ALL),
        .MATCH_SUFFIX(1'b1),
        .MATCH_PREFIX(1'b0)
    ) u_backend (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .timestamp(TIMESTAMP),
        .candidate_valid(out_valid),
        .candidate_ready(out_ready),
        .candidate_seed(out_seed),
        .candidate_public_key(out_public_key),
        .uart_tx(uart_tx)
    );
endmodule
