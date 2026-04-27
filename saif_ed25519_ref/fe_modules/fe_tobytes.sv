module fe_tobytes (
    input  wire signed [319:0] h,     // 10 x 32-bit values packed into 320 bits
    output wire  [7:0] s [31:0]
);

    // Internal registers for unpacked h values
    reg signed [31:0] h0, h1, h2, h3, h4, h5, h6, h7, h8, h9;
    reg signed [31:0] q;
    reg signed [31:0] carry0, carry1, carry2, carry3, carry4;
    reg signed [31:0] carry5, carry6, carry7, carry8, carry9;

    // Shift Left Function (signed logic-safe)
    function signed [31:0] SHL32; 
        input signed [31:0] sig; 
        input [5:0] lshift; 
        reg [31:0] unsigned_s; 
        begin
            unsigned_s = sig;
            SHL32 = (unsigned_s << lshift); 
        end
    endfunction

    // Unpack h and compute everything
    always @(*) begin
        // Unpacking h from 320-bit wire
        h0 = h[31:0];
        h1 = h[63:32];
        h2 = h[95:64];
        h3 = h[127:96];
        h4 = h[159:128];
        h5 = h[191:160];
        h6 = h[223:192];
        h7 = h[255:224];
        h8 = h[287:256];
        h9 = h[319:288];

        // Reduction
        q = (19 * h9 + (1 << 24)) >>> 25;
        q = (h0 + q) >>> 26;
        q = (h1 + q) >>> 25;
        q = (h2 + q) >>> 26;
        q = (h3 + q) >>> 25;
        q = (h4 + q) >>> 26;
        q = (h5 + q) >>> 25;
        q = (h6 + q) >>> 26;
        q = (h7 + q) >>> 25;
        q = (h8 + q) >>> 26;
        q = (h9 + q) >>> 25;

        h0 = h0 + 19 * q;

        carry0 = h0 >>> 26; h1 = h1 + carry0; h0 = h0 - SHL32(carry0, 26); //shift right in Verliog 8er shift right fe C
        carry1 = h1 >>> 25; h2 = h2 + carry1; h1 = h1 - SHL32(carry1, 25);
        carry2 = h2 >>> 26; h3 = h3 + carry2; h2 = h2 - SHL32(carry2, 26);
        carry3 = h3 >>> 25; h4 = h4 + carry3; h3 = h3 - SHL32(carry3, 25);
        carry4 = h4 >>> 26; h5 = h5 + carry4; h4 = h4 - SHL32(carry4, 26);
        carry5 = h5 >>> 25; h6 = h6 + carry5; h5 = h5 - SHL32(carry5, 25);
        carry6 = h6 >>> 26; h7 = h7 + carry6; h6 = h6 - SHL32(carry6, 26);
        carry7 = h7 >>> 25; h8 = h8 + carry7; h7 = h7 - SHL32(carry7, 25);
        carry8 = h8 >>> 26; h9 = h9 + carry8; h8 = h8 - SHL32(carry8, 26);
        carry9 = h9 >>> 25; h9 = h9 - SHL32(carry9, 25);
    end

    // Byte serialization
   assign s[0]  = h0 >> 0;
   assign s[1]  = h0 >> 8;
   assign s[2]  = h0 >> 16;
   assign s[3]  = (h0 >> 24) | SHL32(h1, 2);
   assign s[4]  = h1 >> 6;
   assign s[5]  = h1 >> 14;
   assign s[6]  = (h1 >> 22) | SHL32(h2, 3);
   assign s[7]  = h2 >> 5;
   assign s[8]  = h2 >> 13;
   assign s[9]  = (h2 >> 21) | SHL32(h3, 5);
   assign s[10] = h3 >> 3;
   assign s[11] = h3 >> 11;
   assign s[12] = (h3 >> 19) | SHL32(h4, 6);
   assign s[13] = h4 >> 2;
   assign s[14] = h4 >> 10;
   assign s[15] = h4 >> 18;
   assign s[16] = h5 >> 0;
   assign s[17] = h5 >> 8;
   assign s[18] = h5 >> 16;
   assign s[19] = (h5 >> 24) | SHL32(h6, 1);
   assign s[20] = h6 >> 7;
   assign s[21] = h6 >> 15;
   assign s[22] = (h6 >> 23) | SHL32(h7, 3);
   assign s[23] = h7 >> 5;
   assign s[24] = h7 >> 13;
   assign s[25] = (h7 >> 21) | SHL32(h8, 4);
   assign s[26] = h8 >> 4;
   assign s[27] = h8 >> 12;
   assign s[28] = (h8 >> 20) | SHL32(h9, 6);
   assign s[29] = h9 >> 2;
   assign s[30] = h9 >> 10;
   assign s[31] = h9 >> 18;

endmodule
