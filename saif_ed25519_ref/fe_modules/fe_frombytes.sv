module fe_frombytes(
    input  wire [255:0] s,
    output reg  [319:0] h
);
    function automatic [63:0] load_3;
        input integer offset;
        input [255:0] data_in;
    begin
        load_3 = {40'd0,
                  data_in[8*(offset+2)+7 -: 8],
                  data_in[8*(offset+1)+7 -: 8],
                  data_in[8*offset+7 -: 8]};
    end
    endfunction

    function automatic [63:0] load_4;
        input integer offset;
        input [255:0] data_in;
    begin
        load_4 = {32'd0,
                  data_in[8*(offset+3)+7 -: 8],
                  data_in[8*(offset+2)+7 -: 8],
                  data_in[8*(offset+1)+7 -: 8],
                  data_in[8*offset+7 -: 8]};
    end
    endfunction

    // Arithmetic left shift safe for signed
    function automatic signed [63:0] SHL64;
        input signed [63:0] val;
        input integer          sh;
    begin
        SHL64 = val << sh;
    end
    endfunction

    // Intermediate variables
    reg signed [63:0] h0, h1, h2, h3, h4, h5, h6, h7, h8, h9;
    reg signed [63:0] carry0, carry1, carry2, carry3, carry4;
    reg signed [63:0] carry5, carry6, carry7, carry8, carry9;

    always @* begin
        // unpack directly from s
        h0 = load_4(0, s);
        h1 = load_3(4, s) << 6;
        h2 = load_3(7, s) << 5;
        h3 = load_3(10, s) << 3;
        h4 = load_3(13, s) << 2;
        h5 = load_4(16, s);
        h6 = load_3(20, s) << 7;
        h7 = load_3(23, s) << 5;
        h8 = load_3(26, s) << 4;
        h9 = (load_3(29, s) & 64'h007F_FFFF) << 2;

        // first carry chain
        carry9 = (h9 + (1 << 24)) >>> 25; h0 = h0 + carry9 * 19; h9 = h9 - SHL64(carry9, 25);
        carry1 = (h1 + (1 << 24)) >>> 25; h2 = h2 + carry1;         h1 = h1 - SHL64(carry1, 25);
        carry3 = (h3 + (1 << 24)) >>> 25; h4 = h4 + carry3;         h3 = h3 - SHL64(carry3, 25);
        carry5 = (h5 + (1 << 24)) >>> 25; h6 = h6 + carry5;         h5 = h5 - SHL64(carry5, 25);
        carry7 = (h7 + (1 << 24)) >>> 25; h8 = h8 + carry7;         h7 = h7 - SHL64(carry7, 25);

        // second carry chain
        carry0 = (h0 + (1 << 25)) >>> 26; h1 = h1 + carry0;         h0 = h0 - SHL64(carry0, 26);
        carry2 = (h2 + (1 << 25)) >>> 26; h3 = h3 + carry2;         h2 = h2 - SHL64(carry2, 26);
        carry4 = (h4 + (1 << 25)) >>> 26; h5 = h5 + carry4;         h4 = h4 - SHL64(carry4, 26);
        carry6 = (h6 + (1 << 25)) >>> 26; h7 = h7 + carry6;         h6 = h6 - SHL64(carry6, 26);
        carry8 = (h8 + (1 << 25)) >>> 26; h9 = h9 + carry8;         h8 = h8 - SHL64(carry8, 26);

        // pack outputs into flat bus
        h = {h9[31:0], h8[31:0], h7[31:0], h6[31:0],
                  h5[31:0], h4[31:0], h3[31:0], h2[31:0],
                  h1[31:0], h0[31:0]};
    end
endmodule