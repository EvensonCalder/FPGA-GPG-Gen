module fe_isnonzero (
    input  wire [319:0] f_in,   // Flat input: 10 x 32-bit = 320 bits
    output wire         nz      // Output: 1 if f ≠ 0, 0 if f == 0
);

    wire [7:0] s [31:0];        // Array of 32 bytes from fe_tobytes
    wire [255:0] s_packed;      // Packed 256-bit vector for comparison
    wire [255:0] zero = 256'd0; // Zero constant (32 bytes)

    // Convert field element to bytes
    fe_tobytes fe_tobytes_inst (
        .h  (f_in),
        .s  (s)
    );

    // Explicitly pack the byte array into a 256-bit vector
    assign s_packed = {s[31], s[30], s[29], s[28], s[27], s[26], s[25], s[24],
                       s[23], s[22], s[21], s[20], s[19], s[18], s[17], s[16],
                       s[15], s[14], s[13], s[12], s[11], s[10], s[9], s[8],
                       s[7], s[6], s[5], s[4], s[3], s[2], s[1], s[0]};

    // Compare result with zero using constant-time comparison
    crypto_verify_32 cmp (
        .a         (s_packed),
        .b         (zero),
        .diff_flag (nz)
    );

endmodule