`timescale 1ns / 1ps

module ed25519_ge_madd_v1 (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start,
    input  logic signed [319:0] p_X,
    input  logic signed [319:0] p_Y,
    input  logic signed [319:0] p_Z,
    input  logic signed [319:0] p_T,
    input  logic signed [319:0] q_yplusx,
    input  logic signed [319:0] q_yminusx,
    input  logic signed [319:0] q_xy2d,
    output logic signed [319:0] r_X,
    output logic signed [319:0] r_Y,
    output logic signed [319:0] r_Z,
    output logic signed [319:0] r_T,
    output logic                done
);
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_INIT_START,
        ST_INIT_WAIT,
        ST_MUL_START,
        ST_MUL_WAIT,
        ST_FINAL_XY_START,
        ST_FINAL_XY_WAIT,
        ST_FINAL_ZT_START,
        ST_FINAL_ZT_WAIT,
        ST_DONE
    } state_t;

    state_t state;

    logic signed [319:0] p_X_q;
    logic signed [319:0] p_Y_q;
    logic signed [319:0] p_Z_q;
    logic signed [319:0] p_T_q;
    logic signed [319:0] q_yplusx_q;
    logic signed [319:0] q_yminusx_q;
    logic signed [319:0] q_xy2d_q;

    logic signed [319:0] yplusx1;
    logic signed [319:0] yminusx1;
    logic signed [319:0] a;
    logic signed [319:0] b;
    logic signed [319:0] c;
    logic signed [319:0] d;

    logic                addsub0_start;
    logic                addsub0_sub;
    logic signed [319:0] addsub0_f;
    logic signed [319:0] addsub0_g;
    logic signed [319:0] addsub0_h;
    logic                addsub0_done;

    logic                addsub1_start;
    logic                addsub1_sub;
    logic signed [319:0] addsub1_f;
    logic signed [319:0] addsub1_g;
    logic signed [319:0] addsub1_h;
    logic                addsub1_done;

    logic                mul_start;
    logic                mul_start_q;
    logic signed [319:0] mul_a_f;
    logic signed [319:0] mul_a_g;
    logic signed [319:0] mul_b_f;
    logic signed [319:0] mul_b_g;
    logic signed [319:0] mul_c_f;
    logic signed [319:0] mul_c_g;
    logic signed [319:0] mul_a_f_q;
    logic signed [319:0] mul_a_g_q;
    logic signed [319:0] mul_b_f_q;
    logic signed [319:0] mul_b_g_q;
    logic signed [319:0] mul_c_f_q;
    logic signed [319:0] mul_c_g_q;
    logic signed [319:0] mul_a_h;
    logic signed [319:0] mul_b_h;
    logic signed [319:0] mul_c_h;
    logic                mul_a_done;
    logic                mul_b_done;
    logic                mul_c_done;

    ed25519_fe_addsub_pipe u_addsub0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(addsub0_start),
        .sub(addsub0_sub),
        .f(addsub0_f),
        .g(addsub0_g),
        .h(addsub0_h),
        .done(addsub0_done)
    );

    ed25519_fe_addsub_pipe u_addsub1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(addsub1_start),
        .sub(addsub1_sub),
        .f(addsub1_f),
        .g(addsub1_g),
        .h(addsub1_h),
        .done(addsub1_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_a (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul_a_f_q),
        .g(mul_a_g_q),
        .h(mul_a_h),
        .done(mul_a_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_b (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul_b_f_q),
        .g(mul_b_g_q),
        .h(mul_b_h),
        .done(mul_b_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_c (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul_c_f_q),
        .g(mul_c_g_q),
        .h(mul_c_h),
        .done(mul_c_done)
    );

    always_comb begin
        addsub0_start = 1'b0;
        addsub0_sub = 1'b0;
        addsub0_f = 320'sd0;
        addsub0_g = 320'sd0;

        addsub1_start = 1'b0;
        addsub1_sub = 1'b0;
        addsub1_f = 320'sd0;
        addsub1_g = 320'sd0;

        mul_start = 1'b0;
        mul_a_f = 320'sd0;
        mul_a_g = 320'sd0;
        mul_b_f = 320'sd0;
        mul_b_g = 320'sd0;
        mul_c_f = 320'sd0;
        mul_c_g = 320'sd0;

        unique case (state)
            ST_INIT_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b0;
                addsub0_f = p_Y_q;
                addsub0_g = p_X_q;

                addsub1_start = 1'b1;
                addsub1_sub = 1'b1;
                addsub1_f = p_Y_q;
                addsub1_g = p_X_q;
            end

            ST_MUL_START: begin
                mul_start = 1'b1;
                mul_a_f = yplusx1;
                mul_a_g = q_yplusx_q;
                mul_b_f = yminusx1;
                mul_b_g = q_yminusx_q;
                mul_c_f = q_xy2d_q;
                mul_c_g = p_T_q;

                addsub0_start = 1'b1;
                addsub0_sub = 1'b0;
                addsub0_f = p_Z_q;
                addsub0_g = p_Z_q;
            end

            ST_FINAL_XY_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = a;
                addsub0_g = b;

                addsub1_start = 1'b1;
                addsub1_sub = 1'b0;
                addsub1_f = a;
                addsub1_g = b;
            end

            ST_FINAL_ZT_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b0;
                addsub0_f = d;
                addsub0_g = c;

                addsub1_start = 1'b1;
                addsub1_sub = 1'b1;
                addsub1_f = d;
                addsub1_g = c;
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            p_X_q <= 320'sd0;
            p_Y_q <= 320'sd0;
            p_Z_q <= 320'sd0;
            p_T_q <= 320'sd0;
            q_yplusx_q <= 320'sd0;
            q_yminusx_q <= 320'sd0;
            q_xy2d_q <= 320'sd0;
            yplusx1 <= 320'sd0;
            yminusx1 <= 320'sd0;
            a <= 320'sd0;
            b <= 320'sd0;
            c <= 320'sd0;
            d <= 320'sd0;
            r_X <= 320'sd0;
            r_Y <= 320'sd0;
            r_Z <= 320'sd0;
            r_T <= 320'sd0;
            mul_start_q <= 1'b0;
            mul_a_f_q <= 320'sd0;
            mul_a_g_q <= 320'sd0;
            mul_b_f_q <= 320'sd0;
            mul_b_g_q <= 320'sd0;
            mul_c_f_q <= 320'sd0;
            mul_c_g_q <= 320'sd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            mul_start_q <= mul_start;
            if (mul_start) begin
                mul_a_f_q <= mul_a_f;
                mul_a_g_q <= mul_a_g;
                mul_b_f_q <= mul_b_f;
                mul_b_g_q <= mul_b_g;
                mul_c_f_q <= mul_c_f;
                mul_c_g_q <= mul_c_g;
            end

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        p_X_q <= p_X;
                        p_Y_q <= p_Y;
                        p_Z_q <= p_Z;
                        p_T_q <= p_T;
                        q_yplusx_q <= q_yplusx;
                        q_yminusx_q <= q_yminusx;
                        q_xy2d_q <= q_xy2d;
                        state <= ST_INIT_START;
                    end
                end

                ST_INIT_START: begin
                    state <= ST_INIT_WAIT;
                end

                ST_INIT_WAIT: begin
                    if (addsub0_done && addsub1_done) begin
                        yplusx1 <= addsub0_h;
                        yminusx1 <= addsub1_h;
                        state <= ST_MUL_START;
                    end
                end

                ST_MUL_START: begin
                    state <= ST_MUL_WAIT;
                end

                ST_MUL_WAIT: begin
                    if (addsub0_done) begin
                        d <= addsub0_h;
                    end
                    if (mul_a_done && mul_b_done && mul_c_done) begin
                        a <= mul_a_h;
                        b <= mul_b_h;
                        c <= mul_c_h;
                        state <= ST_FINAL_XY_START;
                    end
                end

                ST_FINAL_XY_START: begin
                    state <= ST_FINAL_XY_WAIT;
                end

                ST_FINAL_XY_WAIT: begin
                    if (addsub0_done && addsub1_done) begin
                        r_X <= addsub0_h;
                        r_Y <= addsub1_h;
                        state <= ST_FINAL_ZT_START;
                    end
                end

                ST_FINAL_ZT_START: begin
                    state <= ST_FINAL_ZT_WAIT;
                end

                ST_FINAL_ZT_WAIT: begin
                    if (addsub0_done && addsub1_done) begin
                        r_Z <= addsub0_h;
                        r_T <= addsub1_h;
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
