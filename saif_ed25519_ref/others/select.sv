module select (
    input  wire [4:0]           pos,          // 5-bit position (0-31)
    input  wire signed [7:0]    b,            // Signed 8-bit input
    output wire signed [319:0]  t_yplusx,     // Absolute selected t->yplusx (10 x 32-bit)
    output wire signed [319:0]  t_yminusx,    // Absolute selected t->yminusx
    output wire signed [319:0]  t_xy2d,       // Absolute selected t->xy2d
    output wire                 bnegative     // Sign bit for caller-side sign application
);

    // Intermediate wires for ge_precomp t
    wire signed [319:0] t_yplusx_init, t_yminusx_init, t_xy2d_init; // After ge_precomp_0
    wire signed [319:0] t_yplusx_intermediate [0:8]; // After each cmov
    wire signed [319:0] t_yminusx_intermediate [0:8];
    wire signed [319:0] t_xy2d_intermediate [0:8];
    // Signals for computation
    wire [7:0]  babs;                         // Absolute value of b
    wire [7:0]  shl_out;                      // Output of SHL8
    wire [7:0]  masked_b;                     // (-bnegative) & b
    wire [7:0]  neg_bnegative;                // -bnegative as 8-bit

    // ROM outputs for base[pos][j]
    wire signed [319:0] base_yplusx [0:7];
    wire signed [319:0] base_yminusx [0:7];
    wire signed [319:0] base_xy2d [0:7];

    // Equality checks for babs
    wire eq[1:8];

    // Compute bnegative
    negative neg_inst (
        .b(b),
        .out(bnegative)
    );

    // Compute babs = b - SHL8((-bnegative) & b, 1)
    assign neg_bnegative = bnegative ? 8'hFF : 8'h00; // -bnegative (0 or -1 as 8-bit)
    assign masked_b = neg_bnegative & b;              // (-bnegative) & b
    SHL8 #(
        .WIDTH(8)
    ) shl_inst (
        .s(masked_b),
        .lshift(5'd1),                                // Shift left by 1
        .shl_out(shl_out)
    );
    assign babs = b - shl_out;                        // b - SHL8 result

    // Initialize t with ge_precomp_0 (yplusx = 1, yminusx = 1, xy2d = 0)
    assign t_yplusx_init = {288'h0, 32'h1};          // 1 in LSB 32-bit, rest 0
    assign t_yminusx_init = {288'h0, 32'h1};         // 1 in LSB 32-bit, rest 0
    assign t_xy2d_init = 320'h0;                     // All zeros

    // Instantiate base_rom1 to get base[pos][j] values
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : base_rom_instances
            base_rom1 rom_inst (
                .pos(pos),
                .j(j[2:0]),                          // j as 3-bit
                .t_yplusx(base_yplusx[j]),
                .t_yminusx(base_yminusx[j]),
                .t_xy2d(base_xy2d[j])
            );
        end
    endgenerate

    // Equality checks for babs (1 to 8)
    equal eq1 (.b(babs), .c(8'd1), .out(eq[1]));
    equal eq2 (.b(babs), .c(8'd2), .out(eq[2]));
    equal eq3 (.b(babs), .c(8'd3), .out(eq[3]));
    equal eq4 (.b(babs), .c(8'd4), .out(eq[4]));
    equal eq5 (.b(babs), .c(8'd5), .out(eq[5]));
    equal eq6 (.b(babs), .c(8'd6), .out(eq[6]));
    equal eq7 (.b(babs), .c(8'd7), .out(eq[7]));
    equal eq8 (.b(babs), .c(8'd8), .out(eq[8]));

    // Chain of cmov operations starting from ge_precomp_0
    assign t_yplusx_intermediate[0] = t_yplusx_init;
    assign t_yminusx_intermediate[0] = t_yminusx_init;
    assign t_xy2d_intermediate[0] = t_xy2d_init;

    genvar i;
    generate
        for (i = 1; i <= 8; i = i + 1) begin : cmov_chain
            cmov cmov_inst (
                .t_yplusx_in(t_yplusx_intermediate[i-1]),
                .t_yminusx_in(t_yminusx_intermediate[i-1]),
                .t_xy2d_in(t_xy2d_intermediate[i-1]),
                .u_yplusx(base_yplusx[i-1]),
                .u_yminusx(base_yminusx[i-1]),
                .u_xy2d(base_xy2d[i-1]),
                .b(eq[i]),
                .t_yplusx_out(t_yplusx_intermediate[i]),
                .t_yminusx_out(t_yminusx_intermediate[i]),
                .t_xy2d_out(t_xy2d_intermediate[i])
            );
        end
    endgenerate

    assign t_yplusx = t_yplusx_intermediate[8];
    assign t_yminusx = t_yminusx_intermediate[8];
    assign t_xy2d = t_xy2d_intermediate[8];

endmodule
