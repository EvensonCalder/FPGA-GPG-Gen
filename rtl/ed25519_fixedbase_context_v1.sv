`timescale 1ns / 1ps

module ed25519_fixedbase_context_v1 (
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
    localparam logic signed [319:0] FE_ZERO = 320'sd0;
    localparam logic signed [319:0] FE_ONE  = {288'd0, 32'd1};

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_SELECT_ODD_START,
        ST_SELECT_ODD_WAIT,
        ST_MADD_ODD_START,
        ST_MADD_ODD_WAIT,
        ST_CONV_ODD_START,
        ST_CONV_ODD_WAIT,
        ST_NEXT_ODD,
        ST_DBL1_START,
        ST_DBL1_WAIT,
        ST_CONV_DBL1_START,
        ST_CONV_DBL1_WAIT,
        ST_DBLN_START,
        ST_DBLN_WAIT,
        ST_CONV_DBLN_START,
        ST_CONV_DBLN_WAIT,
        ST_SELECT_EVEN_START,
        ST_SELECT_EVEN_WAIT,
        ST_MADD_EVEN_START,
        ST_MADD_EVEN_WAIT,
        ST_CONV_EVEN_START,
        ST_CONV_EVEN_WAIT,
        ST_NEXT_EVEN,
        ST_DONE
    } state_t;

    state_t state;

    logic [5:0] idx;
    logic [1:0] dbl_count;

    logic signed [7:0] digit [0:63];

    logic signed [319:0] h_X;
    logic signed [319:0] h_Y;
    logic signed [319:0] h_Z;
    logic signed [319:0] h_T;

    logic signed [319:0] p1_X;
    logic signed [319:0] p1_Y;
    logic signed [319:0] p1_Z;
    logic signed [319:0] p1_T;

    logic signed [319:0] p2_X;
    logic signed [319:0] p2_Y;
    logic signed [319:0] p2_Z;

    logic                select_start;
    logic signed [319:0] sel_yplusx;
    logic signed [319:0] sel_yminusx;
    logic signed [319:0] sel_xy2d;
    logic                select_done;

    logic                madd_start;
    logic signed [319:0] madd_X;
    logic signed [319:0] madd_Y;
    logic signed [319:0] madd_Z;
    logic signed [319:0] madd_T;
    logic                madd_done;

    logic                dbl_start;
    logic signed [319:0] dbl_X;
    logic signed [319:0] dbl_Y;
    logic signed [319:0] dbl_Z;
    logic signed [319:0] dbl_T;
    logic                dbl_done;

    logic                conv_start;
    logic                conv_to_p3;
    logic signed [319:0] conv_X;
    logic signed [319:0] conv_Y;
    logic signed [319:0] conv_Z;
    logic signed [319:0] conv_T;
    logic                conv_done;

    ed25519_scalar_recode_4bit u_recode (
        .scalar(scalar),
        .digit(digit)
    );

    ed25519_fixedbase_table_select_pipe u_select (
        .clk(clk),
        .rst_n(rst_n),
        .start(select_start),
        .pos(idx[5:1]),
        .digit(digit[idx]),
        .yplusx(sel_yplusx),
        .yminusx(sel_yminusx),
        .xy2d(sel_xy2d),
        .done(select_done)
    );

    ed25519_ge_madd_v1 u_madd (
        .clk(clk),
        .rst_n(rst_n),
        .start(madd_start),
        .p_X(h_X),
        .p_Y(h_Y),
        .p_Z(h_Z),
        .p_T(h_T),
        .q_yplusx(sel_yplusx),
        .q_yminusx(sel_yminusx),
        .q_xy2d(sel_xy2d),
        .r_X(madd_X),
        .r_Y(madd_Y),
        .r_Z(madd_Z),
        .r_T(madd_T),
        .done(madd_done)
    );

    ed25519_ge_p2_dbl_v1 u_dbl (
        .clk(clk),
        .rst_n(rst_n),
        .start(dbl_start),
        .p_X(p2_X),
        .p_Y(p2_Y),
        .p_Z(p2_Z),
        .r_X(dbl_X),
        .r_Y(dbl_Y),
        .r_Z(dbl_Z),
        .r_T(dbl_T),
        .done(dbl_done)
    );

    ed25519_ge_p1p1_to_p2p3_v1 u_conv (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv_start),
        .to_p3(conv_to_p3),
        .p_X(p1_X),
        .p_Y(p1_Y),
        .p_Z(p1_Z),
        .p_T(p1_T),
        .r_X(conv_X),
        .r_Y(conv_Y),
        .r_Z(conv_Z),
        .r_T(conv_T),
        .done(conv_done)
    );

    always_comb begin
        select_start = 1'b0;
        madd_start = 1'b0;
        dbl_start = 1'b0;
        conv_start = 1'b0;
        conv_to_p3 = 1'b1;

        unique case (state)
            ST_SELECT_ODD_START,
            ST_SELECT_EVEN_START: begin
                select_start = 1'b1;
            end

            ST_MADD_ODD_START,
            ST_MADD_EVEN_START: begin
                madd_start = 1'b1;
            end

            ST_DBL1_START,
            ST_DBLN_START: begin
                dbl_start = 1'b1;
            end

            ST_CONV_ODD_START,
            ST_CONV_DBLN_START,
            ST_CONV_EVEN_START: begin
                conv_start = 1'b1;
                conv_to_p3 = 1'b1;
            end

            ST_CONV_DBL1_START: begin
                conv_start = 1'b1;
                conv_to_p3 = 1'b0;
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            idx <= 6'd0;
            dbl_count <= 2'd0;
            h_X <= FE_ZERO;
            h_Y <= FE_ZERO;
            h_Z <= FE_ZERO;
            h_T <= FE_ZERO;
            p1_X <= FE_ZERO;
            p1_Y <= FE_ZERO;
            p1_Z <= FE_ZERO;
            p1_T <= FE_ZERO;
            p2_X <= FE_ZERO;
            p2_Y <= FE_ZERO;
            p2_Z <= FE_ZERO;
            r_X <= FE_ZERO;
            r_Y <= FE_ZERO;
            r_Z <= FE_ZERO;
            r_T <= FE_ZERO;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        h_X <= FE_ZERO;
                        h_Y <= FE_ONE;
                        h_Z <= FE_ONE;
                        h_T <= FE_ZERO;
                        idx <= 6'd1;
                        state <= ST_SELECT_ODD_START;
                    end
                end

                ST_SELECT_ODD_START: begin
                    state <= ST_SELECT_ODD_WAIT;
                end

                ST_SELECT_ODD_WAIT: begin
                    if (select_done) begin
                        state <= ST_MADD_ODD_START;
                    end
                end

                ST_MADD_ODD_START: begin
                    state <= ST_MADD_ODD_WAIT;
                end

                ST_MADD_ODD_WAIT: begin
                    if (madd_done) begin
                        p1_X <= madd_X;
                        p1_Y <= madd_Y;
                        p1_Z <= madd_Z;
                        p1_T <= madd_T;
                        state <= ST_CONV_ODD_START;
                    end
                end

                ST_CONV_ODD_START: begin
                    state <= ST_CONV_ODD_WAIT;
                end

                ST_CONV_ODD_WAIT: begin
                    if (conv_done) begin
                        h_X <= conv_X;
                        h_Y <= conv_Y;
                        h_Z <= conv_Z;
                        h_T <= conv_T;
                        state <= ST_NEXT_ODD;
                    end
                end

                ST_NEXT_ODD: begin
                    if (idx == 6'd63) begin
                        p2_X <= h_X;
                        p2_Y <= h_Y;
                        p2_Z <= h_Z;
                        dbl_count <= 2'd0;
                        state <= ST_DBL1_START;
                    end else begin
                        idx <= idx + 6'd2;
                        state <= ST_SELECT_ODD_START;
                    end
                end

                ST_DBL1_START: begin
                    state <= ST_DBL1_WAIT;
                end

                ST_DBL1_WAIT: begin
                    if (dbl_done) begin
                        p1_X <= dbl_X;
                        p1_Y <= dbl_Y;
                        p1_Z <= dbl_Z;
                        p1_T <= dbl_T;
                        state <= ST_CONV_DBL1_START;
                    end
                end

                ST_CONV_DBL1_START: begin
                    state <= ST_CONV_DBL1_WAIT;
                end

                ST_CONV_DBL1_WAIT: begin
                    if (conv_done) begin
                        p2_X <= conv_X;
                        p2_Y <= conv_Y;
                        p2_Z <= conv_Z;
                        dbl_count <= 2'd1;
                        state <= ST_DBLN_START;
                    end
                end

                ST_DBLN_START: begin
                    state <= ST_DBLN_WAIT;
                end

                ST_DBLN_WAIT: begin
                    if (dbl_done) begin
                        p1_X <= dbl_X;
                        p1_Y <= dbl_Y;
                        p1_Z <= dbl_Z;
                        p1_T <= dbl_T;
                        state <= ST_CONV_DBLN_START;
                    end
                end

                ST_CONV_DBLN_START: begin
                    state <= ST_CONV_DBLN_WAIT;
                end

                ST_CONV_DBLN_WAIT: begin
                    if (conv_done) begin
                        if (dbl_count == 2'd3) begin
                            h_X <= conv_X;
                            h_Y <= conv_Y;
                            h_Z <= conv_Z;
                            h_T <= conv_T;
                            idx <= 6'd0;
                            state <= ST_SELECT_EVEN_START;
                        end else begin
                            p2_X <= conv_X;
                            p2_Y <= conv_Y;
                            p2_Z <= conv_Z;
                            dbl_count <= dbl_count + 2'd1;
                            state <= ST_DBLN_START;
                        end
                    end
                end

                ST_SELECT_EVEN_START: begin
                    state <= ST_SELECT_EVEN_WAIT;
                end

                ST_SELECT_EVEN_WAIT: begin
                    if (select_done) begin
                        state <= ST_MADD_EVEN_START;
                    end
                end

                ST_MADD_EVEN_START: begin
                    state <= ST_MADD_EVEN_WAIT;
                end

                ST_MADD_EVEN_WAIT: begin
                    if (madd_done) begin
                        p1_X <= madd_X;
                        p1_Y <= madd_Y;
                        p1_Z <= madd_Z;
                        p1_T <= madd_T;
                        state <= ST_CONV_EVEN_START;
                    end
                end

                ST_CONV_EVEN_START: begin
                    state <= ST_CONV_EVEN_WAIT;
                end

                ST_CONV_EVEN_WAIT: begin
                    if (conv_done) begin
                        h_X <= conv_X;
                        h_Y <= conv_Y;
                        h_Z <= conv_Z;
                        h_T <= conv_T;
                        state <= ST_NEXT_EVEN;
                    end
                end

                ST_NEXT_EVEN: begin
                    if (idx == 6'd62) begin
                        state <= ST_DONE;
                    end else begin
                        idx <= idx + 6'd2;
                        state <= ST_SELECT_EVEN_START;
                    end
                end

                ST_DONE: begin
                    r_X <= h_X;
                    r_Y <= h_Y;
                    r_Z <= h_Z;
                    r_T <= h_T;
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
