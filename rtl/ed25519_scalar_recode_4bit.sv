`timescale 1ns / 1ps

module ed25519_scalar_recode_4bit (
    input  logic [255:0] scalar,
    output logic signed [7:0] digit [0:63]
);
    always_comb begin
        logic signed [8:0] e [0:64];
        logic signed [8:0] carry;

        for (int i = 0; i < 64; i++) begin
            e[i] = {5'd0, scalar[4*i +: 4]};
        end
        e[64] = 9'sd0;

        carry = 9'sd0;
        for (int i = 0; i < 63; i++) begin
            e[i] = e[i] + carry;
            carry = (e[i] + 9'sd8) >>> 4;
            e[i] = e[i] - (carry <<< 4);
        end
        e[63] = e[63] + carry;

        for (int i = 0; i < 64; i++) begin
            digit[i] = e[i][7:0];
        end
    end
endmodule
