module SHL8 #(
    parameter WIDTH = 8  // Define bit-width, default to 8 for SHL8
)(
    input  signed [WIDTH-1:0] s,          // Signed input
    input  [4:0] lshift,                  // Shift amount (max 31 for 32-bit)
    output signed [WIDTH-1:0] shl_out     // Shifted output
);
    // Safe signed left shift using unsigned intermediate value
    wire [WIDTH-1:0] u_s = s;  // Cast to unsigned (Verilog auto zero-extends)
    assign shl_out = $signed(u_s << lshift); // Perform shift and cast back to signed
endmodule
