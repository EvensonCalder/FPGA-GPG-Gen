`timescale 1ns / 1ps

module ed25519_fixedbase_context_v3_x3 (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [2:0]   start,
    input  logic [255:0] scalar0,
    input  logic [255:0] scalar1,
    input  logic [255:0] scalar2,
    output logic signed [319:0] r0_X, r0_Y, r0_Z, r0_T,
    output logic signed [319:0] r1_X, r1_Y, r1_Z, r1_T,
    output logic signed [319:0] r2_X, r2_Y, r2_Z, r2_T,
    output logic [2:0]   done
);
    logic [2:0] sel_req;
    logic [2:0] sel_grant;
    logic [4:0] sel_pos0, sel_pos1, sel_pos2;
    logic signed [7:0] sel_digit0, sel_digit1, sel_digit2;
    logic signed [319:0] bus_yplusx, bus_yminusx, bus_xy2d;
    logic [2:0] sel_done;

    ed25519_fixedbase_select_shared u_shared_sel (
        .clk(clk), .rst_n(rst_n),
        .req(sel_req),
        .pos0(sel_pos0), .pos1(sel_pos1), .pos2(sel_pos2),
        .digit0(sel_digit0), .digit1(sel_digit1), .digit2(sel_digit2),
        .grant(sel_grant),
        .yplusx(bus_yplusx), .yminusx(bus_yminusx), .xy2d(bus_xy2d),
        .done(sel_done)
    );

    ed25519_fixedbase_context_v3_shared u_ctx0 (
        .clk(clk), .rst_n(rst_n), .start(start[0]), .scalar(scalar0),
        .sel_req(sel_req[0]), .sel_grant_me(sel_grant[0]),
        .sel_pos(sel_pos0), .sel_digit(sel_digit0),
        .bus_yplusx(bus_yplusx), .bus_yminusx(bus_yminusx), .bus_xy2d(bus_xy2d),
        .sel_done_me(sel_done[0]),
        .r_X(r0_X), .r_Y(r0_Y), .r_Z(r0_Z), .r_T(r0_T), .done(done[0])
    );

    ed25519_fixedbase_context_v3_shared u_ctx1 (
        .clk(clk), .rst_n(rst_n), .start(start[1]), .scalar(scalar1),
        .sel_req(sel_req[1]), .sel_grant_me(sel_grant[1]),
        .sel_pos(sel_pos1), .sel_digit(sel_digit1),
        .bus_yplusx(bus_yplusx), .bus_yminusx(bus_yminusx), .bus_xy2d(bus_xy2d),
        .sel_done_me(sel_done[1]),
        .r_X(r1_X), .r_Y(r1_Y), .r_Z(r1_Z), .r_T(r1_T), .done(done[1])
    );

    ed25519_fixedbase_context_v3_shared u_ctx2 (
        .clk(clk), .rst_n(rst_n), .start(start[2]), .scalar(scalar2),
        .sel_req(sel_req[2]), .sel_grant_me(sel_grant[2]),
        .sel_pos(sel_pos2), .sel_digit(sel_digit2),
        .bus_yplusx(bus_yplusx), .bus_yminusx(bus_yminusx), .bus_xy2d(bus_xy2d),
        .sel_done_me(sel_done[2]),
        .r_X(r2_X), .r_Y(r2_Y), .r_Z(r2_Z), .r_T(r2_T), .done(done[2])
    );
endmodule
