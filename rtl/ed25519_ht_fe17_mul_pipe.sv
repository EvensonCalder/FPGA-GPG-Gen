`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_mul_pipe (
    input  logic   clk,
    input  logic   rst_n,
    input  logic   in_valid,
    input  fe17_t  a,
    input  fe17_t  b,
    output logic   out_valid,
    output fe17_t  out
);
    localparam logic [16:0] LIMB_MASK = 17'h1ffff;

    logic [63:0] coeff_next [0:28];
    logic [63:0] coeff_q    [0:28];
    logic [79:0] fold_next  [0:14];
    logic [79:0] fold_q     [0:14];
    logic [95:0] carry1_next [0:14];
    logic [95:0] carry1_q    [0:14];
    logic [95:0] carry2_next [0:14];
    logic [95:0] carry2_q    [0:14];
    logic [95:0] carry3_next [0:14];
    logic [95:0] carry3_q    [0:14];

    logic [254:0] packed_next;
    logic [254:0] reduced_once;
    logic [254:0] reduced_twice;
    logic [254:0] field_p;
    logic [5:0] valid_pipe;

    always_comb begin
        for (int i = 0; i < 29; i++)
            coeff_next[i] = 64'd0;

        for (int i = 0; i < FE17_LIMBS; i++) begin
            for (int j = 0; j < FE17_LIMBS; j++) begin
                coeff_next[i + j] = coeff_next[i + j]
                    + (64'(fe17_limb(a, i)) * 64'(fe17_limb(b, j)));
            end
        end
    end

    always_comb begin
        for (int i = 0; i < FE17_LIMBS; i++) begin
            fold_next[i] = 80'(coeff_q[i]);
            if ((i + FE17_LIMBS) < 29)
                fold_next[i] = fold_next[i] + (80'(coeff_q[i + FE17_LIMBS]) * 80'd19);
        end
    end

    task automatic carry_pass(
        input  logic [95:0] in_limbs [0:14],
        output logic [95:0] out_limbs [0:14]
    );
        logic [95:0] tmp [0:14];
        logic [95:0] carry;
        begin
            for (int i = 0; i < FE17_LIMBS; i++)
                tmp[i] = in_limbs[i];

            for (int i = 0; i < FE17_LIMBS - 1; i++) begin
                carry = tmp[i] >> FE17_LIMB_BITS;
                tmp[i] = tmp[i] & 96'(LIMB_MASK);
                tmp[i + 1] = tmp[i + 1] + carry;
            end

            carry = tmp[FE17_LIMBS - 1] >> FE17_LIMB_BITS;
            tmp[FE17_LIMBS - 1] = tmp[FE17_LIMBS - 1] & 96'(LIMB_MASK);
            tmp[0] = tmp[0] + (carry * 96'd19);

            for (int i = 0; i < FE17_LIMBS; i++)
                out_limbs[i] = tmp[i];
        end
    endtask

    always_comb begin
        logic [95:0] fold_ext [0:14];
        for (int i = 0; i < FE17_LIMBS; i++)
            fold_ext[i] = 96'(fold_q[i]);
        carry_pass(fold_ext, carry1_next);
    end

    always_comb begin
        carry_pass(carry1_q, carry2_next);
    end

    always_comb begin
        carry_pass(carry2_q, carry3_next);
    end

    always_comb begin
        packed_next = 255'd0;
        field_p = 255'd0;
        for (int i = 0; i < FE17_LIMBS; i++) begin
            packed_next[i * FE17_LIMB_BITS +: FE17_LIMB_BITS] = carry3_q[i][16:0];
            field_p[i * FE17_LIMB_BITS +: FE17_LIMB_BITS] = (i == 0) ? 17'h1ffed : LIMB_MASK;
        end

        reduced_once = (packed_next >= field_p) ? (packed_next - field_p) : packed_next;
        reduced_twice = (reduced_once >= field_p) ? (reduced_once - field_p) : reduced_once;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 6'd0;
            out_valid <= 1'b0;
            out <= '0;
            for (int i = 0; i < 29; i++)
                coeff_q[i] <= 64'd0;
            for (int i = 0; i < FE17_LIMBS; i++) begin
                fold_q[i] <= 80'd0;
                carry1_q[i] <= 96'd0;
                carry2_q[i] <= 96'd0;
                carry3_q[i] <= 96'd0;
            end
        end else begin
            valid_pipe <= {valid_pipe[4:0], in_valid};
            out_valid <= valid_pipe[5];

            for (int i = 0; i < 29; i++)
                coeff_q[i] <= coeff_next[i];
            for (int i = 0; i < FE17_LIMBS; i++) begin
                fold_q[i] <= fold_next[i];
                carry1_q[i] <= carry1_next[i];
                carry2_q[i] <= carry2_next[i];
                carry3_q[i] <= carry3_next[i];
            end
            out <= fe17_t'(reduced_twice);
        end
    end
endmodule
