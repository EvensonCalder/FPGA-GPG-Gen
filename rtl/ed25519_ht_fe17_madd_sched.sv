`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;
import ed25519_ht_scalar_sched_pkg::*;

module ed25519_ht_fe17_madd_sched #(
    parameter integer CONTEXTS = 4
) (
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic [CONTEXTS-1:0]  start,
    output logic [CONTEXTS-1:0]  start_ready,
    input  fe17_t                p_X [0:CONTEXTS-1],
    input  fe17_t                p_Y [0:CONTEXTS-1],
    input  fe17_t                p_Z [0:CONTEXTS-1],
    input  fe17_t                p_T [0:CONTEXTS-1],
    input  fe17_t                q_yplusx [0:CONTEXTS-1],
    input  fe17_t                q_yminusx [0:CONTEXTS-1],
    input  fe17_t                q_xy2d [0:CONTEXTS-1],

    output logic [CONTEXTS-1:0]  done,
    output fe17_t                r_X [0:CONTEXTS-1],
    output fe17_t                r_Y [0:CONTEXTS-1],
    output fe17_t                r_Z [0:CONTEXTS-1],
    output fe17_t                r_T [0:CONTEXTS-1]
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;
    localparam int CTX_BITS = (CONTEXTS <= 1) ? 1 : $clog2(CONTEXTS);

    typedef enum logic [2:0] {
        CTX_IDLE,
        CTX_PHASE0,
        CTX_WAIT0,
        CTX_EFGH,
        CTX_EFGH_WAIT,
        CTX_PHASE1,
        CTX_WAIT1,
        CTX_DONE
    } ctx_state_t;

    ctx_state_t ctx_state [0:CONTEXTS-1];
    logic [CTX_BITS-1:0] rr_ptr;
    logic [CTX_BITS-1:0] start_idx;
    logic [CTX_BITS-1:0] efgh_idx;
    logic start_found;
    logic start_accept;
    logic start_prep_active_q;
    logic efgh_found;
    logic [CTX_BITS-1:0] start_ctx_q;
    logic [CTX_BITS-1:0] efgh_ctx_q;
    fe17_t start_px_q, start_py_q, start_pz_q;
    fe17_t efgh_a_q, efgh_b_q, efgh_c_q, efgh_d_q;
    fe17_t pt_q [0:CONTEXTS-1];
    fe17_t qypx_q [0:CONTEXTS-1], qymx_q [0:CONTEXTS-1], qxy2d_q [0:CONTEXTS-1];
    fe17_t yplusx [0:CONTEXTS-1], yminusx [0:CONTEXTS-1];
    fe17_t a_reg [0:CONTEXTS-1], b_reg [0:CONTEXTS-1], c_reg [0:CONTEXTS-1], d_reg [0:CONTEXTS-1];
    fe17_t e_reg [0:CONTEXTS-1], f_reg [0:CONTEXTS-1], g_reg [0:CONTEXTS-1], h_reg [0:CONTEXTS-1];
    logic issued_a [0:CONTEXTS-1], issued_b [0:CONTEXTS-1], issued_c [0:CONTEXTS-1];
    logic issued_x [0:CONTEXTS-1], issued_y [0:CONTEXTS-1], issued_z [0:CONTEXTS-1], issued_t [0:CONTEXTS-1];
    logic got_a [0:CONTEXTS-1], got_b [0:CONTEXTS-1], got_c [0:CONTEXTS-1];
    logic got_x [0:CONTEXTS-1], got_y [0:CONTEXTS-1], got_z [0:CONTEXTS-1], got_t [0:CONTEXTS-1];
    logic start_prep_pending [0:CONTEXTS-1];

    logic issue0_valid, issue1_valid;
    scalar_mul_tag_t issue0_tag, issue1_tag;
    fe17_t issue0_a, issue0_b, issue1_a, issue1_b;
    logic retire0_valid, retire1_valid;
    scalar_mul_tag_t retire0_tag, retire1_tag;
    fe17_t retire0_y, retire1_y;
    fe17_t start_yplusx;
    fe17_t start_yminusx;
    fe17_t start_d;
    fe17_t efgh_e;
    fe17_t efgh_f;
    fe17_t efgh_g;
    fe17_t efgh_h;

    function automatic fe17_t fe_add(input fe17_t x, input fe17_t y);
        logic [255:0] raw, red1, red2;
        begin
            raw = 256'(x) + 256'(y);
            red1 = (raw >= 256'(FIELD_P)) ? (raw - 256'(FIELD_P)) : raw;
            red2 = (red1 >= 256'(FIELD_P)) ? (red1 - 256'(FIELD_P)) : red1;
            return fe17_t'(red2[254:0]);
        end
    endfunction

    function automatic fe17_t fe_sub(input fe17_t x, input fe17_t y);
        logic [255:0] raw;
        begin
            raw = (256'(x) >= 256'(y)) ? (256'(x) - 256'(y)) : (256'(x) + 256'(FIELD_P) - 256'(y));
            return fe17_t'(raw[254:0]);
        end
    endfunction

    function automatic logic [CTX_BITS-1:0] wrap_ctx(input int unsigned value);
        int unsigned v;
        begin
            v = value;
            if (value >= CONTEXTS)
                v = value - CONTEXTS;
            return v[CTX_BITS-1:0];
        end
    endfunction

    function automatic logic ctx_issue_ready(input int unsigned c);
        return ((ctx_state[c] == CTX_PHASE0) && !start_prep_pending[c] && (!issued_a[c] || !issued_b[c] || !issued_c[c])) ||
               ((ctx_state[c] == CTX_PHASE1) && (!issued_x[c] || !issued_y[c] || !issued_z[c] || !issued_t[c]));
    endfunction

    function automatic scalar_mul_op_t first_pending_op(input int unsigned c);
        if (ctx_state[c] == CTX_PHASE0) begin
            if (!issued_b[c]) return OP_MADD_B;
            if (!issued_a[c]) return OP_MADD_A;
            if (!issued_c[c]) return OP_MADD_C;
        end else if (ctx_state[c] == CTX_PHASE1) begin
            if (!issued_x[c]) return OP_MADD_X;
            if (!issued_y[c]) return OP_MADD_Y;
            if (!issued_z[c]) return OP_MADD_Z;
            if (!issued_t[c]) return OP_MADD_T;
        end
        return OP_NONE;
    endfunction

    function automatic scalar_mul_op_t second_pending_op(input int unsigned c, input scalar_mul_op_t first_op);
        if (ctx_state[c] == CTX_PHASE0) begin
            if (!issued_b[c] && first_op != OP_MADD_B) return OP_MADD_B;
            if (!issued_a[c] && first_op != OP_MADD_A) return OP_MADD_A;
            if (!issued_c[c] && first_op != OP_MADD_C) return OP_MADD_C;
        end else if (ctx_state[c] == CTX_PHASE1) begin
            if (!issued_x[c] && first_op != OP_MADD_X) return OP_MADD_X;
            if (!issued_y[c] && first_op != OP_MADD_Y) return OP_MADD_Y;
            if (!issued_z[c] && first_op != OP_MADD_Z) return OP_MADD_Z;
            if (!issued_t[c] && first_op != OP_MADD_T) return OP_MADD_T;
        end
        return OP_NONE;
    endfunction

    function automatic fe17_t operand_a(input int unsigned c, input scalar_mul_op_t op);
        unique case (op)
            OP_MADD_B: return yplusx[c];
            OP_MADD_A: return yminusx[c];
            OP_MADD_C: return pt_q[c];
            OP_MADD_X: return e_reg[c];
            OP_MADD_Y: return g_reg[c];
            OP_MADD_Z: return f_reg[c];
            OP_MADD_T: return e_reg[c];
            default: return '0;
        endcase
    endfunction

    function automatic fe17_t operand_b(input int unsigned c, input scalar_mul_op_t op);
        unique case (op)
            OP_MADD_B: return qypx_q[c];
            OP_MADD_A: return qymx_q[c];
            OP_MADD_C: return qxy2d_q[c];
            OP_MADD_X: return f_reg[c];
            OP_MADD_Y: return h_reg[c];
            OP_MADD_Z: return g_reg[c];
            OP_MADD_T: return h_reg[c];
            default: return '0;
        endcase
    endfunction

    function automatic logic issued_now(input int unsigned c, input scalar_mul_op_t op);
        return (issue0_valid && issue0_tag.ctx == c[4:0] && issue0_tag.op == op) ||
               (issue1_valid && issue1_tag.ctx == c[4:0] && issue1_tag.op == op);
    endfunction

    function automatic logic retire_now(input int unsigned c, input scalar_mul_op_t op);
        return (retire0_valid && retire0_tag.ctx == c[4:0] && retire0_tag.op == op) ||
               (retire1_valid && retire1_tag.ctx == c[4:0] && retire1_tag.op == op);
    endfunction

    ed25519_ht_scalar_mul_issue2 u_issue2 (
        .clk(clk), .rst_n(rst_n),
        .issue0_valid(issue0_valid), .issue0_tag(issue0_tag), .issue0_a(issue0_a), .issue0_b(issue0_b),
        .issue1_valid(issue1_valid), .issue1_tag(issue1_tag), .issue1_a(issue1_a), .issue1_b(issue1_b),
        .retire0_valid(retire0_valid), .retire0_tag(retire0_tag), .retire0_y(retire0_y),
        .retire1_valid(retire1_valid), .retire1_tag(retire1_tag), .retire1_y(retire1_y)
    );

    always_comb begin
        issue0_valid = 1'b0;
        issue1_valid = 1'b0;
        issue0_tag = '{ctx: 5'd0, op: OP_NONE};
        issue1_tag = '{ctx: 5'd0, op: OP_NONE};
        issue0_a = '0; issue0_b = '0;
        issue1_a = '0; issue1_b = '0;
        start_found = 1'b0;
        start_accept = 1'b0;
        start_idx = rr_ptr;
        efgh_found = 1'b0;
        efgh_idx = rr_ptr;

        for (int n = 0; n < CONTEXTS; n++) begin
            int unsigned c;
            c = wrap_ctx(rr_ptr + n);
            if (!start_found && ctx_state[c] == CTX_IDLE) begin
                start_found = 1'b1;
                start_idx = c[CTX_BITS-1:0];
            end
            if (!efgh_found && ctx_state[c] == CTX_EFGH) begin
                efgh_found = 1'b1;
                efgh_idx = c[CTX_BITS-1:0];
            end
            if (!issue0_valid && ctx_issue_ready(c)) begin
                scalar_mul_op_t op0, op1;
                op0 = first_pending_op(c);
                op1 = second_pending_op(c, op0);
                issue0_valid = op0 != OP_NONE;
                issue0_tag = '{ctx: c[4:0], op: op0};
                issue1_valid = op1 != OP_NONE;
                issue1_tag = '{ctx: c[4:0], op: op1};
            end
        end

        start_yplusx = fe_add(start_py_q, start_px_q);
        start_yminusx = fe_sub(start_py_q, start_px_q);
        start_d = fe_add(start_pz_q, start_pz_q);
        start_accept = start_found && start[start_idx];
        efgh_e = fe_sub(efgh_b_q, efgh_a_q);
        efgh_h = fe_add(efgh_b_q, efgh_a_q);
        efgh_f = fe_sub(efgh_d_q, efgh_c_q);
        efgh_g = fe_add(efgh_d_q, efgh_c_q);

        if (issue0_valid) begin
            issue0_a = operand_a(issue0_tag.ctx, issue0_tag.op);
            issue0_b = operand_b(issue0_tag.ctx, issue0_tag.op);
        end
        if (issue1_valid) begin
            issue1_a = operand_a(issue1_tag.ctx, issue1_tag.op);
            issue1_b = operand_b(issue1_tag.ctx, issue1_tag.op);
        end

        for (int i = 0; i < CONTEXTS; i++) begin
            start_ready[i] = start_found && (i[CTX_BITS-1:0] == start_idx);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr <= '0;
            start_prep_active_q <= 1'b0;
            start_ctx_q <= '0;
            start_px_q <= '0;
            start_py_q <= '0;
            start_pz_q <= '0;
            efgh_ctx_q <= '0;
            efgh_a_q <= '0;
            efgh_b_q <= '0;
            efgh_c_q <= '0;
            efgh_d_q <= '0;
            for (int i = 0; i < CONTEXTS; i++) begin
                ctx_state[i] <= CTX_IDLE;
                done[i] <= 1'b0;
                pt_q[i] <= '0;
                qypx_q[i] <= '0; qymx_q[i] <= '0; qxy2d_q[i] <= '0;
                yplusx[i] <= '0; yminusx[i] <= '0;
                a_reg[i] <= '0; b_reg[i] <= '0; c_reg[i] <= '0; d_reg[i] <= '0;
                e_reg[i] <= '0; f_reg[i] <= '0; g_reg[i] <= '0; h_reg[i] <= '0;
                issued_a[i] <= 1'b0; issued_b[i] <= 1'b0; issued_c[i] <= 1'b0;
                issued_x[i] <= 1'b0; issued_y[i] <= 1'b0; issued_z[i] <= 1'b0; issued_t[i] <= 1'b0;
                got_a[i] <= 1'b0; got_b[i] <= 1'b0; got_c[i] <= 1'b0;
                got_x[i] <= 1'b0; got_y[i] <= 1'b0; got_z[i] <= 1'b0; got_t[i] <= 1'b0;
                start_prep_pending[i] <= 1'b0;
                r_X[i] <= '0; r_Y[i] <= '0; r_Z[i] <= '0; r_T[i] <= '0;
            end
        end else begin
            for (int i = 0; i < CONTEXTS; i++) begin
                done[i] <= 1'b0;

                if (start_prep_active_q && i[CTX_BITS-1:0] == start_ctx_q) begin
                    yplusx[i] <= start_yplusx;
                    yminusx[i] <= start_yminusx;
                    d_reg[i] <= start_d;
                    start_prep_pending[i] <= 1'b0;
                end

                if (start_accept && i[CTX_BITS-1:0] == start_idx) begin
                    pt_q[i] <= p_T[i];
                    qypx_q[i] <= q_yplusx[i]; qymx_q[i] <= q_yminusx[i]; qxy2d_q[i] <= q_xy2d[i];
                    issued_a[i] <= 1'b0; issued_b[i] <= 1'b0; issued_c[i] <= 1'b0;
                    issued_x[i] <= 1'b0; issued_y[i] <= 1'b0; issued_z[i] <= 1'b0; issued_t[i] <= 1'b0;
                    got_a[i] <= 1'b0; got_b[i] <= 1'b0; got_c[i] <= 1'b0;
                    got_x[i] <= 1'b0; got_y[i] <= 1'b0; got_z[i] <= 1'b0; got_t[i] <= 1'b0;
                    start_prep_pending[i] <= 1'b1;
                    ctx_state[i] <= CTX_PHASE0;
                end

                if (retire0_valid && retire0_tag.ctx == i[4:0]) begin
                    unique case (retire0_tag.op)
                        OP_MADD_A: begin a_reg[i] <= retire0_y; got_a[i] <= 1'b1; end
                        OP_MADD_B: begin b_reg[i] <= retire0_y; got_b[i] <= 1'b1; end
                        OP_MADD_C: begin c_reg[i] <= retire0_y; got_c[i] <= 1'b1; end
                        OP_MADD_X: begin r_X[i] <= retire0_y; got_x[i] <= 1'b1; end
                        OP_MADD_Y: begin r_Y[i] <= retire0_y; got_y[i] <= 1'b1; end
                        OP_MADD_Z: begin r_Z[i] <= retire0_y; got_z[i] <= 1'b1; end
                        OP_MADD_T: begin r_T[i] <= retire0_y; got_t[i] <= 1'b1; end
                        default: begin
                        end
                    endcase
                end
                if (retire1_valid && retire1_tag.ctx == i[4:0]) begin
                    unique case (retire1_tag.op)
                        OP_MADD_A: begin a_reg[i] <= retire1_y; got_a[i] <= 1'b1; end
                        OP_MADD_B: begin b_reg[i] <= retire1_y; got_b[i] <= 1'b1; end
                        OP_MADD_C: begin c_reg[i] <= retire1_y; got_c[i] <= 1'b1; end
                        OP_MADD_X: begin r_X[i] <= retire1_y; got_x[i] <= 1'b1; end
                        OP_MADD_Y: begin r_Y[i] <= retire1_y; got_y[i] <= 1'b1; end
                        OP_MADD_Z: begin r_Z[i] <= retire1_y; got_z[i] <= 1'b1; end
                        OP_MADD_T: begin r_T[i] <= retire1_y; got_t[i] <= 1'b1; end
                        default: begin
                        end
                    endcase
                end

                unique case (ctx_state[i])
                    CTX_PHASE0: begin
                        if (issued_now(i, OP_MADD_A)) issued_a[i] <= 1'b1;
                        if (issued_now(i, OP_MADD_B)) issued_b[i] <= 1'b1;
                        if (issued_now(i, OP_MADD_C)) issued_c[i] <= 1'b1;
                        if ((issued_a[i] || issued_now(i, OP_MADD_A)) &&
                            (issued_b[i] || issued_now(i, OP_MADD_B)) &&
                            (issued_c[i] || issued_now(i, OP_MADD_C))) begin
                            ctx_state[i] <= CTX_WAIT0;
                        end
                    end
                    CTX_WAIT0: begin
                        if ((got_a[i] || retire_now(i, OP_MADD_A)) &&
                            (got_b[i] || retire_now(i, OP_MADD_B)) &&
                            (got_c[i] || retire_now(i, OP_MADD_C))) begin
                            ctx_state[i] <= CTX_EFGH;
                        end
                    end
                    CTX_EFGH: begin
                        if (efgh_found && i[CTX_BITS-1:0] == efgh_idx) begin
                            efgh_ctx_q <= efgh_idx;
                            efgh_a_q <= a_reg[i];
                            efgh_b_q <= b_reg[i];
                            efgh_c_q <= c_reg[i];
                            efgh_d_q <= d_reg[i];
                            ctx_state[i] <= CTX_EFGH_WAIT;
                        end
                    end
                    CTX_EFGH_WAIT: begin
                        if (i[CTX_BITS-1:0] == efgh_ctx_q) begin
                            e_reg[i] <= efgh_e;
                            h_reg[i] <= efgh_h;
                            f_reg[i] <= efgh_f;
                            g_reg[i] <= efgh_g;
                            ctx_state[i] <= CTX_PHASE1;
                        end
                    end
                    CTX_PHASE1: begin
                        if (issued_now(i, OP_MADD_X)) issued_x[i] <= 1'b1;
                        if (issued_now(i, OP_MADD_Y)) issued_y[i] <= 1'b1;
                        if (issued_now(i, OP_MADD_Z)) issued_z[i] <= 1'b1;
                        if (issued_now(i, OP_MADD_T)) issued_t[i] <= 1'b1;
                        if ((issued_x[i] || issued_now(i, OP_MADD_X)) &&
                            (issued_y[i] || issued_now(i, OP_MADD_Y)) &&
                            (issued_z[i] || issued_now(i, OP_MADD_Z)) &&
                            (issued_t[i] || issued_now(i, OP_MADD_T))) begin
                            ctx_state[i] <= CTX_WAIT1;
                        end
                    end
                    CTX_WAIT1: begin
                        if ((got_x[i] || retire_now(i, OP_MADD_X)) &&
                            (got_y[i] || retire_now(i, OP_MADD_Y)) &&
                            (got_z[i] || retire_now(i, OP_MADD_Z)) &&
                            (got_t[i] || retire_now(i, OP_MADD_T))) begin
                            ctx_state[i] <= CTX_DONE;
                        end
                    end
                    CTX_DONE: begin
                        done[i] <= 1'b1;
                        ctx_state[i] <= CTX_IDLE;
                    end
                    default: begin
                    end
                endcase
            end

            start_prep_active_q <= start_accept;
            if (start_accept) begin
                start_ctx_q <= start_idx;
                start_px_q <= p_X[start_idx];
                start_py_q <= p_Y[start_idx];
                start_pz_q <= p_Z[start_idx];
            end

            if (issue1_valid)
                rr_ptr <= wrap_ctx(issue1_tag.ctx + 1);
            else if (issue0_valid)
                rr_ptr <= wrap_ctx(issue0_tag.ctx + 1);
        end
    end
endmodule
