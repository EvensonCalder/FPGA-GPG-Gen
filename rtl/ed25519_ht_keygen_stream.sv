`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_stream #(
    parameter integer LANES = 2,
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1,
    parameter bit NATIVE_COMPRESS = 1'b0,
    parameter bit BATCH_COMPRESS = 1'b0,
    parameter integer BATCH_SIZE = 8,
    parameter bit MULTI_CONTEXT_SCALAR = 1'b0,
    parameter integer SCALAR_CONTEXTS = 16,
    parameter integer POINT_FIFO_DEPTH = 4
) (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         seed_valid,
    output logic         seed_ready,
    input  logic [255:0] seed,

    output logic         out_valid,
    input  logic         out_ready,
    output logic [255:0] out_seed,
    output logic [255:0] out_public_key,

    output logic [63:0]  accepted_count,
    output logic [63:0]  produced_count,
    output logic [63:0]  stall_seed_count,
    output logic [63:0]  stall_output_count
);
    localparam int COMP_LANES = (LANES < 1) ? 1 : ((LANES > 4) ? 4 : LANES);
    localparam int LANE_BITS = (COMP_LANES <= 1) ? 1 : $clog2(COMP_LANES);
    localparam int FIFO_PTR_BITS = (POINT_FIFO_DEPTH <= 2) ? 1 : $clog2(POINT_FIFO_DEPTH);
    localparam int FIFO_COUNT_BITS = FIFO_PTR_BITS + 1;
    localparam logic [FIFO_COUNT_BITS-1:0] FIFO_DEPTH_COUNT = POINT_FIFO_DEPTH;

    logic scalar_point_valid;
    logic scalar_point_ready;
    logic [255:0] scalar_point_seed;
    fe17_t scalar_point_x, scalar_point_y, scalar_point_z;

    logic [255:0] fifo_seed [0:POINT_FIFO_DEPTH-1];
    fe17_t fifo_x [0:POINT_FIFO_DEPTH-1];
    fe17_t fifo_y [0:POINT_FIFO_DEPTH-1];
    fe17_t fifo_z [0:POINT_FIFO_DEPTH-1];
    logic [FIFO_PTR_BITS-1:0] fifo_rd_ptr, fifo_wr_ptr;
    logic [FIFO_COUNT_BITS-1:0] fifo_count;
    logic fifo_push;
    logic fifo_pop;

    logic [COMP_LANES-1:0] comp_in_ready;
    logic [COMP_LANES-1:0] comp_out_valid;
    logic [255:0] comp_out_seed [0:COMP_LANES-1];
    logic [255:0] comp_out_public_key [0:COMP_LANES-1];
    logic [LANE_BITS-1:0] dispatch_lane;
    logic [LANE_BITS-1:0] output_lane;
    logic [LANE_BITS-1:0] selected_output_lane;
    logic selected_output_valid;

    logic batch_in_ready;
    logic batch_out_valid;
    logic [255:0] batch_out_seed;
    logic [255:0] batch_out_public_key;

    assign scalar_point_ready = fifo_count < FIFO_DEPTH_COUNT;
    assign fifo_push = scalar_point_valid && scalar_point_ready;
    assign fifo_pop = (fifo_count != 0) && (BATCH_COMPRESS ? batch_in_ready : comp_in_ready[dispatch_lane]);

    always_comb begin
        selected_output_lane = output_lane;
        selected_output_valid = comp_out_valid[output_lane];
        for (int i = 0; i < COMP_LANES; i++) begin
            if (!selected_output_valid && comp_out_valid[i]) begin
                selected_output_lane = i[LANE_BITS-1:0];
                selected_output_valid = 1'b1;
            end
        end
    end

    assign out_valid = BATCH_COMPRESS ? batch_out_valid : selected_output_valid;
    assign out_seed = BATCH_COMPRESS ? batch_out_seed : comp_out_seed[selected_output_lane];
    assign out_public_key = BATCH_COMPRESS ? batch_out_public_key : comp_out_public_key[selected_output_lane];

    generate
        if (MULTI_CONTEXT_SCALAR) begin : gen_mc_scalar
            ed25519_ht_keygen_scalar_mc_stage #(
                .INIT_FILE(INIT_FILE),
                .CONTEXTS(SCALAR_CONTEXTS),
                .MUL_LANES(MUL_LANES)
            ) u_scalar (
                .clk(clk), .rst_n(rst_n),
                .seed_valid(seed_valid), .seed_ready(seed_ready), .seed(seed),
                .point_valid(scalar_point_valid), .point_ready(scalar_point_ready),
                .point_seed(scalar_point_seed),
                .point_x(scalar_point_x), .point_y(scalar_point_y), .point_z(scalar_point_z)
            );
        end else begin : gen_single_scalar
            ed25519_ht_keygen_scalar_stage #(
                .INIT_FILE(INIT_FILE),
                .MUL_LANES(MUL_LANES)
            ) u_scalar (
                .clk(clk), .rst_n(rst_n),
                .seed_valid(seed_valid), .seed_ready(seed_ready), .seed(seed),
                .point_valid(scalar_point_valid), .point_ready(scalar_point_ready),
                .point_seed(scalar_point_seed),
                .point_x(scalar_point_x), .point_y(scalar_point_y), .point_z(scalar_point_z)
            );
        end
    endgenerate

    generate
        if (BATCH_COMPRESS && (BATCH_SIZE > 32)) begin : gen_batchn_compress
            ed25519_ht_keygen_batchn_pingpong_stage #(
                .BATCH_SIZE(BATCH_SIZE)
            ) u_batch_comp (
                .clk(clk), .rst_n(rst_n),
                .in_valid(fifo_count != 0),
                .in_ready(batch_in_ready),
                .in_seed(fifo_seed[fifo_rd_ptr]),
                .in_x(fifo_x[fifo_rd_ptr]),
                .in_y(fifo_y[fifo_rd_ptr]),
                .in_z(fifo_z[fifo_rd_ptr]),
                .out_valid(batch_out_valid),
                .out_ready(out_ready),
                .out_seed(batch_out_seed),
                .out_public_key(batch_out_public_key)
            );
        end else if (BATCH_COMPRESS && (BATCH_SIZE == 32)) begin : gen_batch32_compress
            ed25519_ht_keygen_batch32_pingpong_stage u_batch_comp (
                .clk(clk), .rst_n(rst_n),
                .in_valid(fifo_count != 0),
                .in_ready(batch_in_ready),
                .in_seed(fifo_seed[fifo_rd_ptr]),
                .in_x(fifo_x[fifo_rd_ptr]),
                .in_y(fifo_y[fifo_rd_ptr]),
                .in_z(fifo_z[fifo_rd_ptr]),
                .out_valid(batch_out_valid),
                .out_ready(out_ready),
                .out_seed(batch_out_seed),
                .out_public_key(batch_out_public_key)
            );
        end else if (BATCH_COMPRESS && (BATCH_SIZE == 16)) begin : gen_batch16_compress
            ed25519_ht_keygen_batch16_pingpong_stage u_batch_comp (
                .clk(clk), .rst_n(rst_n),
                .in_valid(fifo_count != 0),
                .in_ready(batch_in_ready),
                .in_seed(fifo_seed[fifo_rd_ptr]),
                .in_x(fifo_x[fifo_rd_ptr]),
                .in_y(fifo_y[fifo_rd_ptr]),
                .in_z(fifo_z[fifo_rd_ptr]),
                .out_valid(batch_out_valid),
                .out_ready(out_ready),
                .out_seed(batch_out_seed),
                .out_public_key(batch_out_public_key)
            );
        end else if (BATCH_COMPRESS) begin : gen_batch8_compress
            ed25519_ht_keygen_batch8_pingpong_stage u_batch_comp (
                .clk(clk), .rst_n(rst_n),
                .in_valid(fifo_count != 0),
                .in_ready(batch_in_ready),
                .in_seed(fifo_seed[fifo_rd_ptr]),
                .in_x(fifo_x[fifo_rd_ptr]),
                .in_y(fifo_y[fifo_rd_ptr]),
                .in_z(fifo_z[fifo_rd_ptr]),
                .out_valid(batch_out_valid),
                .out_ready(out_ready),
                .out_seed(batch_out_seed),
                .out_public_key(batch_out_public_key)
            );
        end else begin : gen_no_batch_compress
            assign batch_in_ready = 1'b0;
            assign batch_out_valid = 1'b0;
            assign batch_out_seed = 256'd0;
            assign batch_out_public_key = 256'd0;
        end

        for (genvar i = 0; i < COMP_LANES; i++) begin : gen_comp
            if (NATIVE_COMPRESS) begin : gen_native
                ed25519_ht_keygen_native_compress_lane u_comp (
                    .clk(clk), .rst_n(rst_n),
                    .in_valid((fifo_count != 0) && (dispatch_lane == i[LANE_BITS-1:0])),
                    .in_ready(comp_in_ready[i]),
                    .in_seed(fifo_seed[fifo_rd_ptr]),
                    .in_x(fifo_x[fifo_rd_ptr]),
                    .in_y(fifo_y[fifo_rd_ptr]),
                    .in_z(fifo_z[fifo_rd_ptr]),
                    .out_valid(comp_out_valid[i]),
                    .out_ready(out_ready && out_valid && (selected_output_lane == i[LANE_BITS-1:0])),
                    .out_seed(comp_out_seed[i]),
                    .out_public_key(comp_out_public_key[i])
                );
            end else begin : gen_legacy
                ed25519_ht_keygen_compress_lane u_comp (
                    .clk(clk), .rst_n(rst_n),
                    .in_valid((fifo_count != 0) && (dispatch_lane == i[LANE_BITS-1:0])),
                    .in_ready(comp_in_ready[i]),
                    .in_seed(fifo_seed[fifo_rd_ptr]),
                    .in_x(fifo_x[fifo_rd_ptr]),
                    .in_y(fifo_y[fifo_rd_ptr]),
                    .in_z(fifo_z[fifo_rd_ptr]),
                    .out_valid(comp_out_valid[i]),
                    .out_ready(out_ready && out_valid && (selected_output_lane == i[LANE_BITS-1:0])),
                    .out_seed(comp_out_seed[i]),
                    .out_public_key(comp_out_public_key[i])
                );
            end
        end
    endgenerate

    function automatic logic [LANE_BITS-1:0] next_lane(input logic [LANE_BITS-1:0] lane);
        if (lane == COMP_LANES - 1)
            return '0;
        else
            return lane + 1'b1;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_ptr <= '0;
            fifo_wr_ptr <= '0;
            fifo_count <= '0;
            dispatch_lane <= '0;
            output_lane <= '0;
            accepted_count <= 64'd0;
            produced_count <= 64'd0;
            stall_seed_count <= 64'd0;
            stall_output_count <= 64'd0;
            for (int i = 0; i < POINT_FIFO_DEPTH; i++) begin
                fifo_seed[i] <= 256'd0;
                fifo_x[i] <= '0;
                fifo_y[i] <= '0;
                fifo_z[i] <= '0;
            end
        end else begin
            if (seed_valid && seed_ready)
                accepted_count <= accepted_count + 64'd1;
            else if (seed_valid && !seed_ready)
                stall_seed_count <= stall_seed_count + 64'd1;

            if (out_valid && out_ready) begin
                produced_count <= produced_count + 64'd1;
                output_lane <= next_lane(selected_output_lane);
            end else if (out_valid && !out_ready) begin
                stall_output_count <= stall_output_count + 64'd1;
            end

            if (fifo_push) begin
                fifo_seed[fifo_wr_ptr] <= scalar_point_seed;
                fifo_x[fifo_wr_ptr] <= scalar_point_x;
                fifo_y[fifo_wr_ptr] <= scalar_point_y;
                fifo_z[fifo_wr_ptr] <= scalar_point_z;
                fifo_wr_ptr <= fifo_wr_ptr + 1'b1;
            end

            if (fifo_pop) begin
                fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
                if (!BATCH_COMPRESS)
                    dispatch_lane <= next_lane(dispatch_lane);
            end

            unique case ({fifo_push, fifo_pop})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end
endmodule
