module fe_neg (
    input  logic signed [319:0] f,       // Input packed 320-bit array
    output logic signed [319:0] h        // Output packed 320-bit array
);

    always_comb begin
        h[31:0]   = -f[31:0];
        h[63:32]  = -f[63:32];
        h[95:64]  = -f[95:64];
        h[127:96] = -f[127:96];
        h[159:128] = -f[159:128];
        h[191:160] = -f[191:160];
        h[223:192] = -f[223:192];
        h[255:224] = -f[255:224];
        h[287:256] = -f[287:256];
        h[319:288] = -f[319:288];
    end

endmodule
