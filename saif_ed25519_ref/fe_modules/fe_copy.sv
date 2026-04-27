module fe_copy (
    // Inputs: f and g as 320 bit vectors (10 × 32 bit elements each)
    input  signed [319:0] f,
    // Output: result h as 320 bit vector (10 × 32 bit elements)
    output  signed [319:0] h
);


       assign h = {f[319:288], f[287:256], f[255:224],f[223:192], f[191:160], 
              f[159:128], f[127:96], f[95:64], f[63:32], f[31:0]};
 

endmodule