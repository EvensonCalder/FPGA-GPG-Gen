module equal (
    input  wire signed [7:0] b,    // Signed 8-bit input
    input  wire signed [7:0] c,    // Signed 8-bit input
    output wire       out           // 1 if b == c, 0 otherwise
);

    // Internal wires
    wire [7:0]  ub, uc;            // Unsigned 8-bit version of b and c
    wire [7:0]  x;                 // XOR result
    wire [31:0] y;                 // 32-bit intermediate after subtraction

    // Step 1: Convert signed inputs to unsigned
    assign ub = b;                  // Treat b as unsigned
    assign uc = c;                  // Treat c as unsigned

    // Step 2: XOR to check equality (same as C code)
    assign x = ub ^ uc;             // 0 if equal, non-zero if not

    // Step 3: Extend to 32-bit and subtract 1
    assign y = {24'b0, x} - 32'd1;  // Underflows to 4294967295 if x = 0

    // Step 4: Shift right by 31 to get MSB
    assign out = y[31];             // 1 if y = 4294967295, 0 otherwise

endmodule
