`timescale 1ns / 1ps

module ed25519_fixedbase_context_v2_x3 (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [2:0]   start,
    input  logic [255:0] scalar0,
    input  logic [255:0] scalar1,
    input  logic [255:0] scalar2,
    output logic signed [319:0] r0_X,
    output logic signed [319:0] r0_Y,
    output logic signed [319:0] r0_Z,
    output logic signed [319:0] r0_T,
    output logic signed [319:0] r1_X,
    output logic signed [319:0] r1_Y,
    output logic signed [319:0] r1_Z,
    output logic signed [319:0] r1_T,
    output logic signed [319:0] r2_X,
    output logic signed [319:0] r2_Y,
    output logic signed [319:0] r2_Z,
    output logic signed [319:0] r2_T,
    output logic [2:0]   done
);
    ed25519_fixedbase_context_v2_shared u_ctx0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start[0]),
        .scalar(scalar0),
        .r_X(r0_X),
        .r_Y(r0_Y),
        .r_Z(r0_Z),
        .r_T(r0_T),
        .done(done[0])
    );

    ed25519_fixedbase_context_v2_shared u_ctx1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start[1]),
        .scalar(scalar1),
        .r_X(r1_X),
        .r_Y(r1_Y),
        .r_Z(r1_Z),
        .r_T(r1_T),
        .done(done[1])
    );

    ed25519_fixedbase_context_v2_shared u_ctx2 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start[2]),
        .scalar(scalar2),
        .r_X(r2_X),
        .r_Y(r2_Y),
        .r_Z(r2_Z),
        .r_T(r2_T),
        .done(done[2])
    );
endmodule
