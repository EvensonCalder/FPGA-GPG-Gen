module negative (
    input  wire [7:0] b,    // 8-bit signed input (signed char)
    output wire       out   // 1 if negative, 0 otherwise
);

    // Combinational logic: Check the sign bit (MSB)
    assign out = b[7];      // MSB of 8-bit signed value indicates negativity

endmodule