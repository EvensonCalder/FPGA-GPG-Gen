`timescale 1ns / 1ps

module ed25519_fixedbase_context_v3_shared (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] scalar,
    input  logic         sel_grant_me,
    input  logic signed [319:0] bus_yplusx,
    input  logic signed [319:0] bus_yminusx,
    input  logic signed [319:0] bus_xy2d,
    input  logic         sel_done_me,
    output logic         sel_req,
    output logic [4:0]   sel_pos,
    output logic signed [7:0] sel_digit,
    output logic signed [319:0] r_X,
    output logic signed [319:0] r_Y,
    output logic signed [319:0] r_Z,
    output logic signed [319:0] r_T,
    output logic         done
);
    localparam logic signed [319:0] FE_ZERO = 320'sd0;
    localparam logic signed [319:0] FE_ONE  = {288'd0, 32'd1};
    localparam logic [1:0] OP_MADD    = 2'd0;
    localparam logic [1:0] OP_DBL     = 2'd1;
    localparam logic [1:0] OP_CONV_P2 = 2'd2;
    localparam logic [1:0] OP_CONV_P3 = 2'd3;

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_SELECT_REQ,
        ST_SELECT_GRANT,
        ST_MADD_START,
        ST_MADD_WAIT,
        ST_CONV_START,
        ST_CONV_WAIT,
        ST_NEXT,
        ST_DBL1_START,
        ST_DBL1_WAIT,
        ST_CONV_DBL1_START,
        ST_CONV_DBL1_WAIT,
        ST_DBLN_START,
        ST_DBLN_WAIT,
        ST_CONV_DBLN_START,
        ST_CONV_DBLN_WAIT,
        ST_DONE
    } state_t;

    state_t state;

    logic [5:0] idx;
    logic [1:0] dbl_count;
    logic is_odd;
    logic signed [7:0] digit [0:63];

    logic signed [319:0] h_X, h_Y, h_Z, h_T;
    logic signed [319:0] p1_X, p1_Y, p1_Z, p1_T;
    logic signed [319:0] p2_X, p2_Y, p2_Z;

    logic signed [319:0] sel_yplusx_captured;
    logic signed [319:0] sel_yminusx_captured;
    logic signed [319:0] sel_xy2d_captured;

    logic engine_start;
    logic [1:0] engine_op;
    logic signed [319:0] engine_p_X, engine_p_Y, engine_p_Z, engine_p_T;
    logic signed [319:0] engine_X, engine_Y, engine_Z, engine_T;
    logic engine_done;

    ed25519_scalar_recode_4bit u_recode (.scalar(scalar), .digit(digit));

    ed25519_fixedbase_group_engine_v1 u_engine (
        .clk(clk), .rst_n(rst_n), .start(engine_start), .op(engine_op),
        .p_X(engine_p_X), .p_Y(engine_p_Y), .p_Z(engine_p_Z), .p_T(engine_p_T),
        .q_yplusx(sel_yplusx_captured), .q_yminusx(sel_yminusx_captured),
        .q_xy2d(sel_xy2d_captured),
        .r_X(engine_X), .r_Y(engine_Y), .r_Z(engine_Z), .r_T(engine_T),
        .done(engine_done)
    );

    always_comb begin
        sel_req = 1'b0;
        sel_pos = idx[5:1];
        sel_digit = digit[idx];
        engine_start = 1'b0;
        engine_op = OP_MADD;
        engine_p_X = h_X; engine_p_Y = h_Y; engine_p_Z = h_Z; engine_p_T = h_T;

        unique case (state)
            ST_SELECT_REQ: sel_req = 1'b1;
            ST_MADD_START: begin
                engine_start = 1'b1; engine_op = OP_MADD;
                engine_p_X = h_X; engine_p_Y = h_Y; engine_p_Z = h_Z; engine_p_T = h_T;
            end
            ST_DBL1_START, ST_DBLN_START: begin
                engine_start = 1'b1; engine_op = OP_DBL;
                engine_p_X = p2_X; engine_p_Y = p2_Y; engine_p_Z = p2_Z; engine_p_T = FE_ZERO;
            end
            ST_CONV_START, ST_CONV_DBLN_START: begin
                engine_start = 1'b1; engine_op = OP_CONV_P3;
                engine_p_X = p1_X; engine_p_Y = p1_Y; engine_p_Z = p1_Z; engine_p_T = p1_T;
            end
            ST_CONV_DBL1_START: begin
                engine_start = 1'b1; engine_op = OP_CONV_P2;
                engine_p_X = p1_X; engine_p_Y = p1_Y; engine_p_Z = p1_Z; engine_p_T = p1_T;
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE; idx <= 6'd0; dbl_count <= 2'd0; is_odd <= 1'b0;
            h_X <= FE_ZERO; h_Y <= FE_ZERO; h_Z <= FE_ZERO; h_T <= FE_ZERO;
            p1_X <= FE_ZERO; p1_Y <= FE_ZERO; p1_Z <= FE_ZERO; p1_T <= FE_ZERO;
            p2_X <= FE_ZERO; p2_Y <= FE_ZERO; p2_Z <= FE_ZERO;
            sel_yplusx_captured <= FE_ZERO; sel_yminusx_captured <= FE_ZERO; sel_xy2d_captured <= FE_ZERO;
            r_X <= FE_ZERO; r_Y <= FE_ZERO; r_Z <= FE_ZERO; r_T <= FE_ZERO;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            if (sel_done_me) begin
                sel_yplusx_captured <= bus_yplusx;
                sel_yminusx_captured <= bus_yminusx;
                sel_xy2d_captured <= bus_xy2d;
            end

            unique case (state)
                ST_IDLE: if (start) begin
                    h_X <= FE_ZERO; h_Y <= FE_ONE; h_Z <= FE_ONE; h_T <= FE_ZERO;
                    idx <= 6'd1; is_odd <= 1'b1; state <= ST_SELECT_REQ;
                end
                ST_SELECT_REQ: if (sel_grant_me) state <= ST_SELECT_GRANT;
                ST_SELECT_GRANT: if (sel_done_me) state <= ST_MADD_START;
                ST_MADD_START: state <= ST_MADD_WAIT;
                ST_MADD_WAIT: if (engine_done) begin
                    p1_X <= engine_X; p1_Y <= engine_Y; p1_Z <= engine_Z; p1_T <= engine_T;
                    state <= ST_CONV_START;
                end
                ST_CONV_START: state <= ST_CONV_WAIT;
                ST_CONV_WAIT: if (engine_done) begin
                    h_X <= engine_X; h_Y <= engine_Y; h_Z <= engine_Z; h_T <= engine_T;
                    state <= ST_NEXT;
                end
                ST_NEXT: if (is_odd) begin
                    if (idx == 6'd63) begin
                        p2_X <= h_X; p2_Y <= h_Y; p2_Z <= h_Z;
                        dbl_count <= 2'd0; state <= ST_DBL1_START;
                    end else begin idx <= idx + 6'd2; state <= ST_SELECT_REQ; end
                end else begin
                    if (idx == 6'd62) state <= ST_DONE;
                    else begin idx <= idx + 6'd2; state <= ST_SELECT_REQ; end
                end
                ST_DBL1_START: state <= ST_DBL1_WAIT;
                ST_DBL1_WAIT: if (engine_done) begin
                    p1_X <= engine_X; p1_Y <= engine_Y; p1_Z <= engine_Z; p1_T <= engine_T;
                    state <= ST_CONV_DBL1_START;
                end
                ST_CONV_DBL1_START: state <= ST_CONV_DBL1_WAIT;
                ST_CONV_DBL1_WAIT: if (engine_done) begin
                    p2_X <= engine_X; p2_Y <= engine_Y; p2_Z <= engine_Z;
                    dbl_count <= 2'd1; state <= ST_DBLN_START;
                end
                ST_DBLN_START: state <= ST_DBLN_WAIT;
                ST_DBLN_WAIT: if (engine_done) begin
                    p1_X <= engine_X; p1_Y <= engine_Y; p1_Z <= engine_Z; p1_T <= engine_T;
                    state <= ST_CONV_DBLN_START;
                end
                ST_CONV_DBLN_START: state <= ST_CONV_DBLN_WAIT;
                ST_CONV_DBLN_WAIT: if (engine_done) begin
                    if (dbl_count == 2'd3) begin
                        h_X <= engine_X; h_Y <= engine_Y; h_Z <= engine_Z; h_T <= engine_T;
                        idx <= 6'd0; is_odd <= 1'b0; state <= ST_SELECT_REQ;
                    end else begin
                        p2_X <= engine_X; p2_Y <= engine_Y; p2_Z <= engine_Z;
                        dbl_count <= dbl_count + 2'd1; state <= ST_DBLN_START;
                    end
                end
                ST_DONE: begin
                    r_X <= h_X; r_Y <= h_Y; r_Z <= h_Z; r_T <= h_T;
                    done <= 1'b1; state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
