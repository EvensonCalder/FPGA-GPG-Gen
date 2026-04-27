`timescale 1ns / 1ps

module ed25519_ge_p2_dbl_v1 (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start,
    input  logic signed [319:0] p_X,
    input  logic signed [319:0] p_Y,
    input  logic signed [319:0] p_Z,
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
        ST_AA_START,
        ST_MUL_WAIT,
        ST_B_RY_RZ_START,
        ST_B_RY_RZ_WAIT,
        ST_RX_RT_START,
        ST_RX_RT_WAIT,
        ST_DONE
    } state_t;

    state_t state;

    logic signed [319:0] p_X_q;
    logic signed [319:0] p_Y_q;
    logic signed [319:0] p_Z_q;
    logic signed [319:0] p_Z2_q;
    logic signed [319:0] a;
    logic signed [319:0] xx;
    logic signed [319:0] yy;
    logic signed [319:0] zz;
    logic signed [319:0] aa;
    logic signed [319:0] b;

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

    logic                mul_init_start;
    logic                mul_init_start_q;
    logic                mul_aa_start;
    logic                mul_aa_start_q;
    logic signed [319:0] mul_x_h;
    logic signed [319:0] mul_y_h;
    logic signed [319:0] mul_z_h;
    logic signed [319:0] mul_aa_h;
    logic                mul_x_done;
    logic                mul_y_done;
    logic                mul_z_done;
    logic                mul_aa_done;
    logic                mul_x_seen;
    logic                mul_y_seen;
    logic                mul_z_seen;
    logic                mul_aa_seen;

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

    ed25519_fe_mul_wrap_pipe u_mul_xx (
        .clk(clk),
        .reset(rst_n),
        .start(mul_init_start_q),
        .f(p_X_q),
        .g(p_X_q),
        .h(mul_x_h),
        .done(mul_x_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_yy (
        .clk(clk),
        .reset(rst_n),
        .start(mul_init_start_q),
        .f(p_Y_q),
        .g(p_Y_q),
        .h(mul_y_h),
        .done(mul_y_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_zz (
        .clk(clk),
        .reset(rst_n),
        .start(mul_init_start_q),
        .f(p_Z_q),
        .g(p_Z2_q),
        .h(mul_z_h),
        .done(mul_z_done)
    );

    ed25519_fe_mul_wrap_pipe u_mul_aa (
        .clk(clk),
        .reset(rst_n),
        .start(mul_aa_start_q),
        .f(a),
        .g(a),
        .h(mul_aa_h),
        .done(mul_aa_done)
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

        mul_init_start = 1'b0;
        mul_aa_start = 1'b0;

        unique case (state)
            ST_INIT_START: begin
                mul_init_start = 1'b1;

                addsub0_start = 1'b1;
                addsub0_sub = 1'b0;
                addsub0_f = p_X_q;
                addsub0_g = p_Y_q;
            end

            ST_AA_START: begin
                mul_aa_start = 1'b1;
            end

            ST_B_RY_RZ_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b0;
                addsub0_f = yy;
                addsub0_g = xx;

                addsub1_start = 1'b1;
                addsub1_sub = 1'b1;
                addsub1_f = yy;
                addsub1_g = xx;
            end

            ST_RX_RT_START: begin
                addsub0_start = 1'b1;
                addsub0_sub = 1'b1;
                addsub0_f = aa;
                addsub0_g = r_Y;

                addsub1_start = 1'b1;
                addsub1_sub = 1'b1;
                addsub1_f = b;
                addsub1_g = r_Z;
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
            p_Z2_q <= 320'sd0;
            a <= 320'sd0;
            xx <= 320'sd0;
            yy <= 320'sd0;
            zz <= 320'sd0;
            aa <= 320'sd0;
            b <= 320'sd0;
            r_X <= 320'sd0;
            r_Y <= 320'sd0;
            r_Z <= 320'sd0;
            r_T <= 320'sd0;
            mul_init_start_q <= 1'b0;
            mul_aa_start_q <= 1'b0;
            mul_x_seen <= 1'b0;
            mul_y_seen <= 1'b0;
            mul_z_seen <= 1'b0;
            mul_aa_seen <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            mul_init_start_q <= mul_init_start;
            mul_aa_start_q <= mul_aa_start;

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        p_X_q <= p_X;
                        p_Y_q <= p_Y;
                        p_Z_q <= p_Z;
                        for (int i = 0; i < 10; i++) begin
                            p_Z2_q[32*i +: 32] <= p_Z[32*i +: 32] <<< 1;
                        end
                        mul_x_seen <= 1'b0;
                        mul_y_seen <= 1'b0;
                        mul_z_seen <= 1'b0;
                        mul_aa_seen <= 1'b0;
                        state <= ST_INIT_START;
                    end
                end

                ST_INIT_START: begin
                    state <= ST_INIT_WAIT;
                end

                ST_INIT_WAIT: begin
                    if (addsub0_done) begin
                        a <= addsub0_h;
                        state <= ST_AA_START;
                    end
                end

                ST_AA_START: begin
                    state <= ST_MUL_WAIT;
                end

                ST_MUL_WAIT: begin
                    if (mul_x_done) begin
                        xx <= mul_x_h;
                        mul_x_seen <= 1'b1;
                    end
                    if (mul_y_done) begin
                        yy <= mul_y_h;
                        mul_y_seen <= 1'b1;
                    end
                    if (mul_z_done) begin
                        b <= mul_z_h;
                        mul_z_seen <= 1'b1;
                    end
                    if (mul_aa_done) begin
                        aa <= mul_aa_h;
                        mul_aa_seen <= 1'b1;
                    end
                    if ((mul_x_seen || mul_x_done) &&
                        (mul_y_seen || mul_y_done) &&
                        (mul_z_seen || mul_z_done) &&
                        (mul_aa_seen || mul_aa_done)) begin
                        state <= ST_B_RY_RZ_START;
                    end
                end

                ST_B_RY_RZ_START: begin
                    state <= ST_B_RY_RZ_WAIT;
                end

                ST_B_RY_RZ_WAIT: begin
                    if (addsub0_done && addsub1_done) begin
                        r_Y <= addsub0_h;
                        r_Z <= addsub1_h;
                        state <= ST_RX_RT_START;
                    end
                end

                ST_RX_RT_START: begin
                    state <= ST_RX_RT_WAIT;
                end

                ST_RX_RT_WAIT: begin
                    if (addsub0_done && addsub1_done) begin
                        r_X <= addsub0_h;
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
