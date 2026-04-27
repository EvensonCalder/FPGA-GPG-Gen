`timescale 1ns / 1ps

module ed25519_keygen_x2_pipeline (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         seed_valid,
    output logic         seed_ready,
    input  logic [255:0] seed,
    output logic         busy,
    output logic         candidate_valid,
    input  logic         candidate_ready,
    output logic [255:0] candidate_seed,
    output logic [255:0] candidate_public_key
);
    logic       kg0_busy;
    logic       kg0_done;
    logic [255:0] kg0_seed_out;
    logic [255:0] kg0_public;
    logic       kg0_start;
    logic [255:0] kg0_seed;

    logic       kg1_busy;
    logic       kg1_done;
    logic [255:0] kg1_seed_out;
    logic [255:0] kg1_public;
    logic       kg1_start;
    logic [255:0] kg1_seed;

    logic [255:0] seed_reg;
    logic       seed_has_value;
    logic       output_valid;
    logic       output_lane;

    always_comb begin
        if (!kg0_busy)
            seed_ready = 1'b1;
        else if (!kg1_busy)
            seed_ready = 1'b1;
        else
            seed_ready = 1'b0;
    end

    assign busy = seed_has_value || kg0_busy || kg1_busy || output_valid;

    ed25519_keygen_core u_keygen0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(kg0_start),
        .seed(kg0_seed),
        .busy(kg0_busy),
        .done(kg0_done),
        .seed_out(kg0_seed_out),
        .expanded_secret(),
        .public_key(kg0_public)
    );

    ed25519_keygen_core u_keygen1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(kg1_start),
        .seed(kg1_seed),
        .busy(kg1_busy),
        .done(kg1_done),
        .seed_out(kg1_seed_out),
        .expanded_secret(),
        .public_key(kg1_public)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seed_reg <= 256'd0;
            seed_has_value <= 1'b0;
            kg0_start <= 1'b0;
            kg0_seed <= 256'd0;
            kg1_start <= 1'b0;
            kg1_seed <= 256'd0;
            output_valid <= 1'b0;
            output_lane <= 1'b0;
            candidate_valid <= 1'b0;
            candidate_seed <= 256'd0;
            candidate_public_key <= 256'd0;
        end else begin
            kg0_start <= 1'b0;
            kg1_start <= 1'b0;
            if (candidate_valid && candidate_ready)
                candidate_valid <= 1'b0;

            if (seed_valid && seed_ready) begin
                seed_reg <= seed;
                seed_has_value <= 1'b1;
            end

            if (seed_has_value && !output_valid) begin
                if (!kg0_busy && !kg0_start) begin
                    kg0_seed <= seed_reg;
                    kg0_start <= 1'b1;
                    seed_has_value <= 1'b0;
                end else if (!kg1_busy && !kg1_start) begin
                    kg1_seed <= seed_reg;
                    kg1_start <= 1'b1;
                    seed_has_value <= 1'b0;
                end
            end

            if (kg0_done && !output_valid) begin
                output_valid <= 1'b1;
                output_lane <= 1'b0;
            end else if (kg1_done && !output_valid) begin
                output_valid <= 1'b1;
                output_lane <= 1'b1;
            end

            if (output_valid && !candidate_valid) begin
                candidate_valid <= 1'b1;
                if (!output_lane) begin
                    candidate_seed <= kg0_seed_out;
                    candidate_public_key <= kg0_public;
                end else begin
                    candidate_seed <= kg1_seed_out;
                    candidate_public_key <= kg1_public;
                end
                output_valid <= 1'b0;
            end
        end
    end
endmodule
