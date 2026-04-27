module fe_isnegative (
    input  wire signed [319:0] h,    // Packed 10 x 32-bit elements
    output wire is_negative          // 1 if s[0] & 1, else 0
);

    wire [7:0] s [31:0];             // 32-byte output from fe_tobytes

    // Instantiate fe_tobytes module
    fe_tobytes fe_to_bytes_inst (
        .h(h),
        .s(s)
    );

    // Extract least significant bit of s[0]
    assign is_negative = s[0] & 1;    

endmodule
