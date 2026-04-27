`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_to_fe10 (
    input  fe17_t              fe17,
    output logic signed [319:0] fe10
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;
    logic [254:0] v;
    logic [31:0] limb [0:9];

    always_comb begin
        v = (fe17 >= FIELD_P) ? (fe17 - FIELD_P) : fe17;

        for (int i = 0; i < 10; i++)
            limb[i] = 32'd0;

        limb[0][25:0] = v[25:0];
        limb[1][24:0] = v[50:26];
        limb[2][25:0] = v[76:51];
        limb[3][24:0] = v[101:77];
        limb[4][25:0] = v[127:102];
        limb[5][24:0] = v[152:128];
        limb[6][25:0] = v[178:153];
        limb[7][24:0] = v[203:179];
        limb[8][25:0] = v[229:204];
        limb[9][24:0] = v[254:230];

        for (int i = 0; i < 10; i++)
            fe10[i * 32 +: 32] = limb[i];
    end
endmodule
