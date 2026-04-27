module crypto_verify_32 (
    input  wire [255:0] a,
    input  wire [255:0] b,
    output wire         diff_flag
);
    wire [31:0] byte_diff;
    
    assign byte_diff[0]  = |(a[7:0]   ^ b[7:0]);
    assign byte_diff[1]  = |(a[15:8]  ^ b[15:8]);
    assign byte_diff[2]  = |(a[23:16] ^ b[23:16]);
    assign byte_diff[3]  = |(a[31:24] ^ b[31:24]);
    assign byte_diff[4]  = |(a[39:32] ^ b[39:32]);
    assign byte_diff[5]  = |(a[47:40] ^ b[47:40]);
    assign byte_diff[6]  = |(a[55:48] ^ b[55:48]);
    assign byte_diff[7]  = |(a[63:56] ^ b[63:56]);
    assign byte_diff[8]  = |(a[71:64] ^ b[71:64]);
    assign byte_diff[9]  = |(a[79:72] ^ b[79:72]);
    assign byte_diff[10] = |(a[87:80] ^ b[87:80]);
    assign byte_diff[11] = |(a[95:88] ^ b[95:88]);
    assign byte_diff[12] = |(a[103:96]  ^ b[103:96]);
    assign byte_diff[13] = |(a[111:104] ^ b[111:104]);
    assign byte_diff[14] = |(a[119:112] ^ b[119:112]);
    assign byte_diff[15] = |(a[127:120] ^ b[127:120]);
    assign byte_diff[16] = |(a[135:128] ^ b[135:128]);
    assign byte_diff[17] = |(a[143:136] ^ b[143:136]);
    assign byte_diff[18] = |(a[151:144] ^ b[151:144]);
    assign byte_diff[19] = |(a[159:152] ^ b[159:152]);
    assign byte_diff[20] = |(a[167:160] ^ b[167:160]);
    assign byte_diff[21] = |(a[175:168] ^ b[175:168]);
    assign byte_diff[22] = |(a[183:176] ^ b[183:176]);
    assign byte_diff[23] = |(a[191:184] ^ b[191:184]);
    assign byte_diff[24] = |(a[199:192] ^ b[199:192]);
    assign byte_diff[25] = |(a[207:200] ^ b[207:200]);
    assign byte_diff[26] = |(a[215:208] ^ b[215:208]);
    assign byte_diff[27] = |(a[223:216] ^ b[223:216]);
    assign byte_diff[28] = |(a[231:224] ^ b[231:224]);
    assign byte_diff[29] = |(a[239:232] ^ b[239:232]);
    assign byte_diff[30] = |(a[247:240] ^ b[247:240]);
    assign byte_diff[31] = |(a[255:248] ^ b[255:248]);

    assign diff_flag = |byte_diff; // if any byte differs, output 1 (non-zero)

endmodule
