`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fe17_encode_public (
    input  fe17_t        x_affine,
    input  fe17_t        y_affine,
    output logic [255:0] public_key
);
    localparam logic [254:0] FIELD_P = (255'(1) << 255) - 255'd19;

    logic [254:0] y0;
    logic [254:0] y1;
    logic [254:0] y_canon;

    always_comb begin
        y0 = (y_affine >= FIELD_P) ? (y_affine - FIELD_P) : y_affine;
        y1 = (y0 >= FIELD_P) ? (y0 - FIELD_P) : y0;
        y_canon = y1;
        public_key = {x_affine[0], y_canon[254:0]};
    end
endmodule
