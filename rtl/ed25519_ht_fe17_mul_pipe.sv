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

    logic [33:0] product_next [0:14][0:14];
    logic [33:0] product_q    [0:14][0:14];
    logic [63:0] coeff_part_next [0:28][0:2];
    logic [63:0] coeff_part_q    [0:28][0:2];
    logic [63:0] coeff_next [0:28];
    logic [63:0] coeff_q    [0:28];
    logic [79:0] fold_next  [0:14];
    logic [79:0] fold_q     [0:14];
    logic [95:0] carry_next [0:17][0:14];
    logic [95:0] carry_q    [0:17][0:14];

    logic [254:0] packed_next;
    logic [254:0] reduced_once;
    logic [254:0] reduced_twice;
    logic [254:0] field_p;
    logic [22:0] valid_pipe;

    always_comb begin
        for (int i = 0; i < FE17_LIMBS; i++) begin
            for (int j = 0; j < FE17_LIMBS; j++) begin
                product_next[i][j] = 34'(fe17_limb(a, i)) * 34'(fe17_limb(b, j));
            end
        end
    end

    always_comb begin
        for (int i = 0; i < 29; i++) begin
            for (int g = 0; g < 3; g++)
                coeff_part_next[i][g] = 64'd0;
            coeff_next[i] = 64'd0;
        end

        for (int i = 0; i < FE17_LIMBS; i++) begin
            for (int j = 0; j < FE17_LIMBS; j++) begin
                coeff_part_next[i + j][i / 5] = coeff_part_next[i + j][i / 5] + 64'(product_q[i][j]);
            end
        end

        for (int i = 0; i < 29; i++)
            coeff_next[i] = coeff_part_q[i][0] + coeff_part_q[i][1] + coeff_part_q[i][2];
    end

    always_comb begin
        for (int i = 0; i < FE17_LIMBS; i++) begin
            fold_next[i] = 80'(coeff_q[i]);
            if ((i + FE17_LIMBS) < 29)
                fold_next[i] = fold_next[i] + (80'(coeff_q[i + FE17_LIMBS]) * 80'd19);
        end
    end

    task automatic carry_group(
        input  logic [95:0] in_limbs [0:14],
        output logic [95:0] out_limbs [0:14]
        ,input int first_limb
        ,input int last_limb
        ,input bit wrap_final
    );
        logic [95:0] tmp [0:14];
        logic [95:0] carry;
        begin
            for (int i = 0; i < FE17_LIMBS; i++)
                tmp[i] = in_limbs[i];

            for (int i = first_limb; i <= last_limb; i++) begin
                carry = tmp[i] >> FE17_LIMB_BITS;
                tmp[i] = tmp[i] & 96'(LIMB_MASK);
                if (i == FE17_LIMBS - 1)
                    tmp[0] = tmp[0] + (carry * 96'd19);
                else if (i == last_limb && !wrap_final)
                    tmp[i + 1] = tmp[i + 1] + carry;
                else if (i != last_limb)
                    tmp[i + 1] = tmp[i + 1] + carry;
            end

            for (int i = 0; i < FE17_LIMBS; i++)
                out_limbs[i] = tmp[i];
        end
    endtask

    always_comb begin
        logic [95:0] fold_ext [0:14];
        for (int i = 0; i < FE17_LIMBS; i++)
            fold_ext[i] = 96'(fold_q[i]);
        carry_group(fold_ext, carry_next[0], 0, 2, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[0], carry_next[1], 3, 5, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[1], carry_next[2], 6, 8, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[2], carry_next[3], 9, 11, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[3], carry_next[4], 12, 13, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[4], carry_next[5], 14, 14, 1'b1);
    end

    always_comb begin
        carry_group(carry_q[5], carry_next[6], 0, 2, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[6], carry_next[7], 3, 5, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[7], carry_next[8], 6, 8, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[8], carry_next[9], 9, 11, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[9], carry_next[10], 12, 13, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[10], carry_next[11], 14, 14, 1'b1);
    end

    always_comb begin
        carry_group(carry_q[11], carry_next[12], 0, 2, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[12], carry_next[13], 3, 5, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[13], carry_next[14], 6, 8, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[14], carry_next[15], 9, 11, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[15], carry_next[16], 12, 13, 1'b0);
    end

    always_comb begin
        carry_group(carry_q[16], carry_next[17], 14, 14, 1'b1);
    end

    always_comb begin
        packed_next = 255'd0;
        field_p = 255'd0;
        for (int i = 0; i < FE17_LIMBS; i++) begin
            packed_next[i * FE17_LIMB_BITS +: FE17_LIMB_BITS] = carry_q[17][i][16:0];
            field_p[i * FE17_LIMB_BITS +: FE17_LIMB_BITS] = (i == 0) ? 17'h1ffed : LIMB_MASK;
        end

        reduced_once = (packed_next >= field_p) ? (packed_next - field_p) : packed_next;
        reduced_twice = (reduced_once >= field_p) ? (reduced_once - field_p) : reduced_once;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 23'd0;
            out_valid <= 1'b0;
            out <= '0;
            for (int i = 0; i < FE17_LIMBS; i++) begin
                for (int j = 0; j < FE17_LIMBS; j++) begin
                    product_q[i][j] <= 34'd0;
                end
            end
            for (int i = 0; i < 29; i++)
                coeff_q[i] <= 64'd0;
            for (int i = 0; i < 29; i++) begin
                for (int g = 0; g < 3; g++)
                    coeff_part_q[i][g] <= 64'd0;
            end
            for (int i = 0; i < FE17_LIMBS; i++) begin
                fold_q[i] <= 80'd0;
                for (int s = 0; s < 18; s++)
                    carry_q[s][i] <= 96'd0;
            end
        end else begin
            valid_pipe <= {valid_pipe[21:0], in_valid};
            out_valid <= valid_pipe[22];

            for (int i = 0; i < FE17_LIMBS; i++) begin
                for (int j = 0; j < FE17_LIMBS; j++) begin
                    product_q[i][j] <= product_next[i][j];
                end
            end
            for (int i = 0; i < 29; i++)
                coeff_q[i] <= coeff_next[i];
            for (int i = 0; i < 29; i++) begin
                for (int g = 0; g < 3; g++)
                    coeff_part_q[i][g] <= coeff_part_next[i][g];
            end
            for (int i = 0; i < FE17_LIMBS; i++) begin
                fold_q[i] <= fold_next[i];
                for (int s = 0; s < 18; s++)
                    carry_q[s][i] <= carry_next[s][i];
            end
            out <= fe17_t'(reduced_twice);
        end
    end
endmodule
