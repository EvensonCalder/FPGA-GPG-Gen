module fe_add (
    // Inputs: f and g as 320+ bit vectors (10 × 32 bit elements each)
    input  signed [319:0] f,
    input  signed [319:0] g,
    // Output: result h as 320+ bit vector (10 × 32 bit elements)
    output reg signed [319:0] h
);



  // Extract individual 32+ bit elements from the 320 bit inputs
  wire signed [63:0] h0, h1, h2, h3, h4, h5, h6, h7, h8, h9;
 

  assign  h0 = f[31:0] + g[31:0];
  assign  h1 = f[63:32] + g[63:32];
  assign  h2 = f[95:64] + g[95:64];
  assign  h3 = f[127:96] + g[127:96];
  assign  h4 = f[159:128] + g[159:128];
  assign  h5 = f[191:160] + g[191:160];
  assign  h6 = f[223:192] + g[223:192];
  assign  h7 = f[255:224] + g[255:224];
  assign  h8 = f[287:256] + g[287:256];
  assign  h9 = f[319:288] + g[319:288];


    assign    h = {h9[31:0], h8[31:0], h7[31:0], h6[31:0], h5[31:0], 
              h4[31:0], h3[31:0], h2[31:0], h1[31:0], h0[31:0]};

endmodule