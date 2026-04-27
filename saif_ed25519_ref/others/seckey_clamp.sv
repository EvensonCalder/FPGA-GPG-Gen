module seckey_clamp (
    input  wire [511:0] input_hashed_seckey, // SHA‑512 output (64 bytes)
    output wire [511:0] output_sk           // clamped secret key
);

    // Byte 0: clear low 3 bits (sk[0] &= 248)
    assign output_sk[  7:  0] = input_hashed_seckey[  7:  0] & 8'b1111_1000;

    // Bytes 1–30 unchanged (sk[1]…sk[30])
    assign output_sk[247:  8] = input_hashed_seckey[247:  8];

    // Byte 31: clear bits 6–7 then set bit 6 (sk[31] &= 63; sk[31] |= 64)
    assign output_sk[255:248] =
        (input_hashed_seckey[255:248] & 8'b0011_1111)  // clear bits 6–7
      | 8'b0100_0000;                                // set bit 6

    // Bytes 32–63 unchanged (sk[32]…sk[63])
    assign output_sk[511:256] = input_hashed_seckey[511:256];

endmodule
