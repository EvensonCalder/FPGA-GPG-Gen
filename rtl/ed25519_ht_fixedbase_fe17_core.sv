`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_fe17_core #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] scalar,
    output fe17_t        r_X,
    output fe17_t        r_Y,
    output fe17_t        r_Z,
    output fe17_t        r_T,
    output logic         done
);
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_START,
        ST_BUSY
    } state_t;

    state_t state;
    logic ctx_start;
    logic ctx_done;
    logic [255:0] scalar_reg;

    assign ctx_start = state == ST_START;
    assign done = ctx_done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            scalar_reg <= 256'd0;
        end else begin
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        scalar_reg <= scalar;
                        state <= ST_START;
                    end
                end
                ST_START: state <= ST_BUSY;
                ST_BUSY: begin
                    if (ctx_done)
                        state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

    ed25519_ht_fixedbase_context #(
        .INIT_FILE(INIT_FILE),
        .MUL_LANES(MUL_LANES)
    ) u_context (
        .clk(clk),
        .rst_n(rst_n),
        .start(ctx_start),
        .scalar(scalar_reg),
        .r_X(r_X), .r_Y(r_Y), .r_Z(r_Z), .r_T(r_T),
        .done(ctx_done)
    );
endmodule
