module fe_cmov (
    input  wire signed [319:0] f_in,  // Input: 320-bit vector (10 x 32-bit signed integers)
    input  wire signed [319:0] g,     // Input: 320-bit vector (10 x 32-bit signed integers)
    input  wire                b,     // Control signal (0 or 1)
    output wire signed [319:0] f_out  // Output: 320-bit vector (10 x 32-bit signed integers)
);
    // Step 1: Extract f_in and g into temporary arrays (like f0, g0 in C)
    wire signed [31:0] f [9:0];
    wire signed [31:0] g_local [9:0];
    wire signed [31:0] x [9:0];       // Differences
    wire signed [31:0] x_masked [9:0]; // Masked differences
    wire signed [31:0] b_neg;          // Negated b as 32-bit mask

    // Step 1: Assign f and g slices
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : extract
            assign f[i] = f_in[i*32 +: 32];
            assign g_local[i] = g[i*32 +: 32];
        end
    endgenerate

    // Step 2: Compute XOR differences (x[i] = f[i] ^ g[i])
    generate
        for (i = 0; i < 10; i = i + 1) begin : xor_diff
            assign x[i] = f[i] ^ g_local[i];
        end
    endgenerate

    // Step 3: Negate b (b = -b in C)
    assign b_neg = -{{31{1'b0}}, b};  // Extend b to 32 bits, then negate

    // Step 4: Mask differences (x[i] &= b)
    generate
        for (i = 0; i < 10; i = i + 1) begin : mask
            assign x_masked[i] = x[i] & b_neg;
        end
    endgenerate

    // Step 5: Update output (f[i] = f[i] ^ x[i])
    generate
        for (i = 0; i < 10; i = i + 1) begin : update
            assign f_out[i*32 +: 32] = f[i] ^ x_masked[i];
        end
    endgenerate
endmodule