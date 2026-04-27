`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe10_to_fe17 (
    input  logic signed [319:0] fe10,
    output fe17_t              fe17
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;

    logic signed [31:0] limb [0:9];
    logic signed [511:0] accum;
    logic signed [511:0] limb_ext [0:9];
    logic [511:0] pos_accum;
    logic [511:0] mod_accum;

    always_comb begin
        accum = 512'sd0;
        for (int i = 0; i < 10; i++) begin
            limb[i] = fe10[i * 32 +: 32];
            limb_ext[i] = {{480{limb[i][31]}}, limb[i]};
        end

        accum = accum + (limb_ext[0] <<< 0);
        accum = accum + (limb_ext[1] <<< 26);
        accum = accum + (limb_ext[2] <<< 51);
        accum = accum + (limb_ext[3] <<< 77);
        accum = accum + (limb_ext[4] <<< 102);
        accum = accum + (limb_ext[5] <<< 128);
        accum = accum + (limb_ext[6] <<< 153);
        accum = accum + (limb_ext[7] <<< 179);
        accum = accum + (limb_ext[8] <<< 204);
        accum = accum + (limb_ext[9] <<< 230);

        pos_accum = accum[511] ? (512'(accum) + (512'(FIELD_P) << 4)) : 512'(accum);
        mod_accum = pos_accum;
        for (int i = 0; i < 20; i++) begin
            if (mod_accum >= 512'(FIELD_P))
                mod_accum = mod_accum - 512'(FIELD_P);
        end
    end

    assign fe17 = fe17_t'(mod_accum[254:0]);
endmodule
