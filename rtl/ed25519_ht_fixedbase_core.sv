`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_core #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] scalar,
    output logic signed [319:0] r_X,
    output logic signed [319:0] r_Y,
    output logic signed [319:0] r_Z,
    output logic signed [319:0] r_T,
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
    fe17_t x17, y17, z17, t17;

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
        .r_X(x17), .r_Y(y17), .r_Z(z17), .r_T(t17),
        .done(ctx_done)
    );

    ed25519_ht_fe17_to_fe10 cX(.fe17(x17), .fe10(r_X));
    ed25519_ht_fe17_to_fe10 cY(.fe17(y17), .fe10(r_Y));
    ed25519_ht_fe17_to_fe10 cZ(.fe17(z17), .fe10(r_Z));
    ed25519_ht_fe17_to_fe10 cT(.fe17(t17), .fe10(r_T));
endmodule
