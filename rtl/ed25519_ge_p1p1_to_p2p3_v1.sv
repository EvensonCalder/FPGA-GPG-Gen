`timescale 1ns / 1ps

module ed25519_ge_p1p1_to_p2p3_v1 (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start,
    input  logic                to_p3,
    input  logic signed [319:0] p_X,
    input  logic signed [319:0] p_Y,
    input  logic signed [319:0] p_Z,
    input  logic signed [319:0] p_T,
    output logic signed [319:0] r_X,
    output logic signed [319:0] r_Y,
    output logic signed [319:0] r_Z,
    output logic signed [319:0] r_T,
    output logic                done
);
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_MUL_START,
        ST_MUL_WAIT,
        ST_DONE
    } state_t;

    state_t state;

    logic                to_p3_q;
    logic signed [319:0] p_X_q;
    logic signed [319:0] p_Y_q;
    logic signed [319:0] p_Z_q;
    logic signed [319:0] p_T_q;

    logic mul_xyz_start;
    logic mul_t_start;
    logic mul_xyz_start_q;
    logic mul_t_start_q;

    logic signed [319:0] mul_x_h;
    logic signed [319:0] mul_y_h;
    logic signed [319:0] mul_z_h;
    logic signed [319:0] mul_t_h;
    logic                mul_x_done;
    logic                mul_y_done;
    logic                mul_z_done;
    logic                mul_t_done;
    logic                mul_x_seen;
    logic                mul_y_seen;
    logic                mul_z_seen;
    logic                mul_t_seen;

    ed25519_fe_mul_wrap_pipe u_mul_x (
        .clk(clk),
        .reset(rst_n),
        .start(mul_xyz_start_q),
        .f(p_X_q),
        .g(p_T_q),
        .h(mul_x_h),
        .done(mul_x_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_y (
        .clk(clk),
        .reset(rst_n),
        .start(mul_xyz_start_q),
        .f(p_Y_q),
        .g(p_Z_q),
        .h(mul_y_h),
        .done(mul_y_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_z (
        .clk(clk),
        .reset(rst_n),
        .start(mul_xyz_start_q),
        .f(p_Z_q),
        .g(p_T_q),
        .h(mul_z_h),
        .done(mul_z_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_t (
        .clk(clk),
        .reset(rst_n),
        .start(mul_t_start_q),
        .f(p_X_q),
        .g(p_Y_q),
        .h(mul_t_h),
        .done(mul_t_done)
    );

    always_comb begin
        mul_xyz_start = 1'b0;
        mul_t_start = 1'b0;

        if (state == ST_MUL_START) begin
            mul_xyz_start = 1'b1;
            mul_t_start = to_p3_q;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            to_p3_q <= 1'b0;
            p_X_q <= 320'sd0;
            p_Y_q <= 320'sd0;
            p_Z_q <= 320'sd0;
            p_T_q <= 320'sd0;
            r_X <= 320'sd0;
            r_Y <= 320'sd0;
            r_Z <= 320'sd0;
            r_T <= 320'sd0;
            mul_xyz_start_q <= 1'b0;
            mul_t_start_q <= 1'b0;
            mul_x_seen <= 1'b0;
            mul_y_seen <= 1'b0;
            mul_z_seen <= 1'b0;
            mul_t_seen <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            mul_xyz_start_q <= mul_xyz_start;
            mul_t_start_q <= mul_t_start;

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        to_p3_q <= to_p3;
                        p_X_q <= p_X;
                        p_Y_q <= p_Y;
                        p_Z_q <= p_Z;
                        p_T_q <= p_T;
                        mul_x_seen <= 1'b0;
                        mul_y_seen <= 1'b0;
                        mul_z_seen <= 1'b0;
                        mul_t_seen <= 1'b0;
                        state <= ST_MUL_START;
                    end
                end

                ST_MUL_START: begin
                    state <= ST_MUL_WAIT;
                end

                ST_MUL_WAIT: begin
                    if (mul_x_done) begin
                        r_X <= mul_x_h;
                        mul_x_seen <= 1'b1;
                    end
                    if (mul_y_done) begin
                        r_Y <= mul_y_h;
                        mul_y_seen <= 1'b1;
                    end
                    if (mul_z_done) begin
                        r_Z <= mul_z_h;
                        mul_z_seen <= 1'b1;
                    end
                    if (mul_t_done) begin
                        r_T <= mul_t_h;
                        mul_t_seen <= 1'b1;
                    end
                    if ((mul_x_seen || mul_x_done) &&
                        (mul_y_seen || mul_y_done) &&
                        (mul_z_seen || mul_z_done) &&
                        (!to_p3_q || mul_t_seen || mul_t_done)) begin
                        if (!to_p3_q) begin
                            r_T <= 320'sd0;
                        end
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
