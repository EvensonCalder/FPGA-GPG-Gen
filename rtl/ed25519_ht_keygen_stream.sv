`timescale 1ns / 1ps

module ed25519_ht_keygen_stream #(
    parameter integer LANES = 1,
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
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
    logic lane_start;
    logic lane_busy;
    logic lane_done;
    logic [255:0] lane_seed_out;
    logic [255:0] lane_public_key;
    logic [511:0] lane_expanded_secret;

    logic result_valid;
    logic [255:0] result_seed;
    logic [255:0] result_public_key;

    assign seed_ready = !lane_busy && !result_valid;
    assign lane_start = seed_valid && seed_ready;

    ed25519_ht_keygen_core #(
        .INIT_FILE(INIT_FILE)
    ) u_lane (
        .clk(clk),
        .rst_n(rst_n),
        .start(lane_start),
        .seed(seed),
        .busy(lane_busy),
        .done(lane_done),
        .seed_out(lane_seed_out),
        .expanded_secret(lane_expanded_secret),
        .public_key(lane_public_key)
    );

    assign out_valid = result_valid;
    assign out_seed = result_seed;
    assign out_public_key = result_public_key;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_valid <= 1'b0;
            result_seed <= 256'd0;
            result_public_key <= 256'd0;
            accepted_count <= 64'd0;
            produced_count <= 64'd0;
            stall_seed_count <= 64'd0;
            stall_output_count <= 64'd0;
        end else begin
            if (seed_valid && seed_ready)
                accepted_count <= accepted_count + 64'd1;
            else if (seed_valid && !seed_ready)
                stall_seed_count <= stall_seed_count + 64'd1;

            if (lane_done) begin
                result_valid <= 1'b1;
                result_seed <= lane_seed_out;
                result_public_key <= lane_public_key;
            end

            if (out_valid && out_ready) begin
                result_valid <= 1'b0;
                produced_count <= produced_count + 64'd1;
            end else if (out_valid && !out_ready) begin
                stall_output_count <= stall_output_count + 64'd1;
            end
        end
    end
endmodule
