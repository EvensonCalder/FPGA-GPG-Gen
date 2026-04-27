package ed25519_ht_fe17_pkg;
    localparam int FE17_LIMBS = 15;
    localparam int FE17_LIMB_BITS = 17;
    localparam int FE17_BITS = FE17_LIMBS * FE17_LIMB_BITS;
    localparam int FE17_CANON_BITS = 255;

    typedef logic [FE17_BITS-1:0] fe17_t;

    function automatic logic [16:0] fe17_limb(input fe17_t value, input int idx);
        return value[idx * FE17_LIMB_BITS +: FE17_LIMB_BITS];
    endfunction

    function automatic fe17_t fe17_pack_limb(input fe17_t value, input int idx, input logic [16:0] limb);
        fe17_t result;
        begin
            result = value;
            result[idx * FE17_LIMB_BITS +: FE17_LIMB_BITS] = limb;
            return result;
        end
    endfunction
endpackage
