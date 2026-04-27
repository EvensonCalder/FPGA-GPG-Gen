`timescale 1ns / 1ps

module ed25519_fixedbase_group_engine_v1 (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start,
    input  logic [1:0]          op,
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
    localparam logic [1:0] OP_MADD    = 2'd0;
    localparam logic [1:0] OP_DBL     = 2'd1;
    localparam logic [1:0] OP_CONV_P2 = 2'd2;
    localparam logic [1:0] OP_CONV_P3 = 2'd3;

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_MADD_INIT_START,
        ST_MADD_INIT_WAIT,
        ST_MADD_INIT_SUB_START,
        ST_MADD_INIT_SUB_WAIT,
        ST_MADD_MUL_START,
        ST_MADD_MUL_WAIT,
        ST_MADD_XY_START,
        ST_MADD_XY_WAIT,
        ST_MADD_XY_ADD_START,
        ST_MADD_XY_ADD_WAIT,
        ST_MADD_ZT_START,
        ST_MADD_ZT_WAIT,
        ST_MADD_ZT_SUB_START,
        ST_MADD_ZT_SUB_WAIT,
        ST_DBL_INIT_START,
        ST_DBL_INIT_WAIT,
        ST_DBL_AA_START,
        ST_DBL_MUL_WAIT,
        ST_DBL_YZ_START,
        ST_DBL_YZ_WAIT,
        ST_DBL_YZ_SUB_START,
        ST_DBL_YZ_SUB_WAIT,
        ST_DBL_XT_START,
        ST_DBL_XT_WAIT,
        ST_DBL_XT_ZT_START,
        ST_DBL_XT_ZT_WAIT,
        ST_CONV_MUL_START,
        ST_CONV_MUL_WAIT,
        ST_DONE
    } state_t;

    state_t state;

    logic [1:0] op_q;
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
    logic signed [319:0] xx;
    logic signed [319:0] yy;
    logic signed [319:0] zz;
    logic signed [319:0] aa;
    logic signed [319:0] p_Z2_q;

    logic                addsub0_start;
    logic                addsub0_sub;
    logic signed [319:0] addsub0_f;
    logic signed [319:0] addsub0_g;
    logic signed [319:0] addsub0_h;
    logic                addsub0_done;

    logic                mul_start;
    logic                mul_start_q;
    logic signed [319:0] mul0_f;
    logic signed [319:0] mul0_g;
    logic signed [319:0] mul1_f;
    logic signed [319:0] mul1_g;
    logic signed [319:0] mul2_f;
    logic signed [319:0] mul2_g;
    logic signed [319:0] mul3_f;
    logic signed [319:0] mul3_g;
    logic signed [319:0] mul0_f_q;
    logic signed [319:0] mul0_g_q;
    logic signed [319:0] mul1_f_q;
    logic signed [319:0] mul1_g_q;
    logic signed [319:0] mul2_f_q;
    logic signed [319:0] mul2_g_q;
    logic signed [319:0] mul3_f_q;
    logic signed [319:0] mul3_g_q;
    logic signed [319:0] mul0_h;
    logic signed [319:0] mul1_h;
    logic signed [319:0] mul2_h;
    logic signed [319:0] mul3_h;
    logic                mul0_done;
    logic                mul1_done;
    logic                mul2_done;
    logic                mul3_done;
    logic                mul0_seen;
    logic                mul1_seen;
    logic                mul2_seen;
    logic                mul3_seen;
    logic                addsub0_seen;

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

    ed25519_fe_mul_wrap_pipe u_mul0 (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul0_f_q),
        .g(mul0_g_q),
        .h(mul0_h),
        .done(mul0_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul1 (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul1_f_q),
        .g(mul1_g_q),
        .h(mul1_h),
        .done(mul1_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul2 (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul2_f_q),
        .g(mul2_g_q),
        .h(mul2_h),
        .done(mul2_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul3 (
        .clk(clk),
        .reset(rst_n),
        .start(mul_start_q),
        .f(mul3_f_q),
        .g(mul3_g_q),
        .h(mul3_h),
        .done(mul3_done)
    );

    always_comb begin
        addsub0_start = 1'b0;
        addsub0_sub = 1'b0;
        addsub0_f = 320'sd0;
        addsub0_g = 320'sd0;
        mul_start = 1'b0;
        mul0_f = 320'sd0;
        mul0_g = 320'sd0;
        mul1_f = 320'sd0;
        mul1_g = 320'sd0;
        mul2_f = 320'sd0;
        mul2_g = 320'sd0;
        mul3_f = 320'sd0;
        mul3_g = 320'sd0;

        unique case (state)
            ST_MADD_INIT_START: begin
                addsub0_start = 1'b1;
                addsub0_f = p_Y_q;
                addsub0_g = p_X_q;
            end

            ST_MADD_INIT_SUB_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = p_Y_q;
                addsub0_g = p_X_q;
            end

            ST_MADD_MUL_START: begin
                mul_start = 1'b1;
                mul0_f = yplusx1;
                mul0_g = q_yplusx_q;
                mul1_f = yminusx1;
                mul1_g = q_yminusx_q;
                mul2_f = q_xy2d_q;
                mul2_g = p_T_q;
                mul3_f = 320'sd0;
                mul3_g = 320'sd0;
                addsub0_start = 1'b1;
                addsub0_f = p_Z_q;
                addsub0_g = p_Z_q;
            end

            ST_MADD_XY_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = a;
                addsub0_g = b;
            end

            ST_MADD_XY_ADD_START: begin
                addsub0_start = 1'b1;
                addsub0_f = a;
                addsub0_g = b;
            end

            ST_MADD_ZT_START: begin
                addsub0_start = 1'b1;
                addsub0_f = d;
                addsub0_g = c;
            end

            ST_MADD_ZT_SUB_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = d;
                addsub0_g = c;
            end

            ST_DBL_INIT_START: begin
                mul_start = 1'b1;
                mul0_f = p_X_q;
                mul0_g = p_X_q;
                mul1_f = p_Y_q;
                mul1_g = p_Y_q;
                mul2_f = p_Z_q;
                mul2_g = p_Z2_q;
                mul3_f = 320'sd0;
                mul3_g = 320'sd0;
                addsub0_start = 1'b1;
                addsub0_f = p_X_q;
                addsub0_g = p_Y_q;
            end

            ST_DBL_AA_START: begin
                mul_start = 1'b1;
                mul0_f = a;
                mul0_g = a;
                mul1_f = 320'sd0;
                mul1_g = 320'sd0;
                mul2_f = 320'sd0;
                mul2_g = 320'sd0;
                mul3_f = 320'sd0;
                mul3_g = 320'sd0;
            end

            ST_DBL_YZ_START: begin
                addsub0_start = 1'b1;
                addsub0_f = yy;
                addsub0_g = xx;
            end

            ST_DBL_YZ_SUB_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = yy;
                addsub0_g = xx;
            end

            ST_DBL_XT_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = aa;
                addsub0_g = r_Y;
            end

            ST_DBL_XT_ZT_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = zz;
                addsub0_g = r_Z;
            end

            ST_CONV_MUL_START: begin
                mul_start = 1'b1;
                mul0_f = p_X_q;
                mul0_g = p_T_q;
                mul1_f = p_Y_q;
                mul1_g = p_Z_q;
                mul2_f = p_Z_q;
                mul2_g = p_T_q;
                mul3_f = p_X_q;
                mul3_g = p_Y_q;
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            op_q <= OP_MADD;
            p_X_q <= 320'sd0;
            p_Y_q <= 320'sd0;
            p_Z_q <= 320'sd0;
            p_T_q <= 320'sd0;
            p_Z2_q <= 320'sd0;
            q_yplusx_q <= 320'sd0;
            q_yminusx_q <= 320'sd0;
            q_xy2d_q <= 320'sd0;
            yplusx1 <= 320'sd0;
            yminusx1 <= 320'sd0;
            a <= 320'sd0;
            b <= 320'sd0;
            c <= 320'sd0;
            d <= 320'sd0;
            xx <= 320'sd0;
            yy <= 320'sd0;
            zz <= 320'sd0;
            aa <= 320'sd0;
            r_X <= 320'sd0;
            r_Y <= 320'sd0;
            r_Z <= 320'sd0;
            r_T <= 320'sd0;
            mul_start_q <= 1'b0;
            mul0_f_q <= 320'sd0;
            mul0_g_q <= 320'sd0;
            mul1_f_q <= 320'sd0;
            mul1_g_q <= 320'sd0;
            mul2_f_q <= 320'sd0;
            mul2_g_q <= 320'sd0;
            mul3_f_q <= 320'sd0;
            mul3_g_q <= 320'sd0;
            mul0_seen <= 1'b0;
            mul1_seen <= 1'b0;
            mul2_seen <= 1'b0;
            mul3_seen <= 1'b0;
            addsub0_seen <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            mul_start_q <= mul_start;
            if (mul_start) begin
                mul0_f_q <= mul0_f;
                mul0_g_q <= mul0_g;
                mul1_f_q <= mul1_f;
                mul1_g_q <= mul1_g;
                mul2_f_q <= mul2_f;
                mul2_g_q <= mul2_g;
                mul3_f_q <= mul3_f;
                mul3_g_q <= mul3_g;
                mul0_seen <= 1'b0;
                mul1_seen <= 1'b0;
                mul2_seen <= 1'b0;
                mul3_seen <= 1'b0;
                addsub0_seen <= 1'b0;
            end

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        op_q <= op;
                        p_X_q <= p_X;
                        p_Y_q <= p_Y;
                        p_Z_q <= p_Z;
                        p_T_q <= p_T;
                        q_yplusx_q <= q_yplusx;
                        q_yminusx_q <= q_yminusx;
                        q_xy2d_q <= q_xy2d;
                        for (int i = 0; i < 10; i++) begin
                            p_Z2_q[32*i +: 32] <= p_Z[32*i +: 32] <<< 1;
                        end
                        unique case (op)
                            OP_MADD: state <= ST_MADD_INIT_START;
                            OP_DBL: state <= ST_DBL_INIT_START;
                            default: state <= ST_CONV_MUL_START;
                        endcase
                    end
                end

                ST_MADD_INIT_START: state <= ST_MADD_INIT_WAIT;
                ST_MADD_INIT_WAIT: begin
                    if (addsub0_done) begin
                        yplusx1 <= addsub0_h;
                        state <= ST_MADD_INIT_SUB_START;
                    end
                end
                ST_MADD_INIT_SUB_START: state <= ST_MADD_INIT_SUB_WAIT;
                ST_MADD_INIT_SUB_WAIT: begin
                    if (addsub0_done) begin
                        yminusx1 <= addsub0_h;
                        state <= ST_MADD_MUL_START;
                    end
                end
                ST_MADD_MUL_START: state <= ST_MADD_MUL_WAIT;
                ST_MADD_MUL_WAIT: begin
                    if (addsub0_done) d <= addsub0_h;
                    if (mul0_done) begin a <= mul0_h; mul0_seen <= 1'b1; end
                    if (mul1_done) begin b <= mul1_h; mul1_seen <= 1'b1; end
                    if (mul2_done) begin c <= mul2_h; mul2_seen <= 1'b1; end
                    if ((mul0_seen || mul0_done) && (mul1_seen || mul1_done) && (mul2_seen || mul2_done)) begin
                        state <= ST_MADD_XY_START;
                    end
                end
                ST_MADD_XY_START: state <= ST_MADD_XY_WAIT;
                ST_MADD_XY_WAIT: begin
                    if (addsub0_done) begin
                        r_X <= addsub0_h;
                        state <= ST_MADD_XY_ADD_START;
                    end
                end
                ST_MADD_XY_ADD_START: state <= ST_MADD_XY_ADD_WAIT;
                ST_MADD_XY_ADD_WAIT: begin
                    if (addsub0_done) begin
                        r_Y <= addsub0_h;
                        state <= ST_MADD_ZT_START;
                    end
                end
                ST_MADD_ZT_START: state <= ST_MADD_ZT_WAIT;
                ST_MADD_ZT_WAIT: begin
                    if (addsub0_done) begin
                        r_Z <= addsub0_h;
                        state <= ST_MADD_ZT_SUB_START;
                    end
                end
                ST_MADD_ZT_SUB_START: state <= ST_MADD_ZT_SUB_WAIT;
                ST_MADD_ZT_SUB_WAIT: begin
                    if (addsub0_done) begin
                        r_T <= addsub0_h;
                        state <= ST_DONE;
                    end
                end

                ST_DBL_INIT_START: state <= ST_DBL_INIT_WAIT;
                ST_DBL_INIT_WAIT: begin
                    if (addsub0_done) begin
                        a <= addsub0_h;
                        addsub0_seen <= 1'b1;
                    end
                    if (mul0_done) begin xx <= mul0_h; mul0_seen <= 1'b1; end
                    if (mul1_done) begin yy <= mul1_h; mul1_seen <= 1'b1; end
                    if (mul2_done) begin zz <= mul2_h; mul2_seen <= 1'b1; end
                    if ((mul0_seen || mul0_done) && (mul1_seen || mul1_done) && (mul2_seen || mul2_done) && (addsub0_seen || addsub0_done)) begin
                        state <= ST_DBL_AA_START;
                    end
                end
                ST_DBL_AA_START: state <= ST_DBL_MUL_WAIT;
                ST_DBL_MUL_WAIT: begin
                    if (mul0_done) begin
                        aa <= mul0_h;
                        state <= ST_DBL_YZ_START;
                    end
                end
                ST_DBL_YZ_START: state <= ST_DBL_YZ_WAIT;
                ST_DBL_YZ_WAIT: begin
                    if (addsub0_done) begin
                        r_Y <= addsub0_h;
                        state <= ST_DBL_YZ_SUB_START;
                    end
                end
                ST_DBL_YZ_SUB_START: state <= ST_DBL_YZ_SUB_WAIT;
                ST_DBL_YZ_SUB_WAIT: begin
                    if (addsub0_done) begin
                        r_Z <= addsub0_h;
                        state <= ST_DBL_XT_START;
                    end
                end
                ST_DBL_XT_START: state <= ST_DBL_XT_WAIT;
                ST_DBL_XT_WAIT: begin
                    if (addsub0_done) begin
                        r_X <= addsub0_h;
                        state <= ST_DBL_XT_ZT_START;
                    end
                end
                ST_DBL_XT_ZT_START: state <= ST_DBL_XT_ZT_WAIT;
                ST_DBL_XT_ZT_WAIT: begin
                    if (addsub0_done) begin
                        r_T <= addsub0_h;
                        state <= ST_DONE;
                    end
                end

                ST_CONV_MUL_START: state <= ST_CONV_MUL_WAIT;
                ST_CONV_MUL_WAIT: begin
                    if (mul0_done) begin r_X <= mul0_h; mul0_seen <= 1'b1; end
                    if (mul1_done) begin r_Y <= mul1_h; mul1_seen <= 1'b1; end
                    if (mul2_done) begin r_Z <= mul2_h; mul2_seen <= 1'b1; end
                    if (mul3_done) begin r_T <= mul3_h; mul3_seen <= 1'b1; end
                    if ((mul0_seen || mul0_done) &&
                        (mul1_seen || mul1_done) &&
                        (mul2_seen || mul2_done) &&
                        (op_q == OP_CONV_P2 || mul3_seen || mul3_done)) begin
                        if (op_q == OP_CONV_P2) begin
                            r_T <= 320'sd0;
                        end
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
