module cmov (
    input  wire signed [319:0] t_yplusx_in,   // Input t->yplusx (fe type: 10 x 32-bit)
    input  wire signed [319:0] t_yminusx_in,  // Input t->yminusx
    input  wire signed [319:0] t_xy2d_in,     // Input t->xy2d
    input  wire signed [319:0] u_yplusx,      // Input u->yplusx
    input  wire signed [319:0] u_yminusx,     // Input u->yminusx
    input  wire signed [319:0] u_xy2d,        // Input u->xy2d
    input  wire                b,             // Control signal (0 or 1)
    output wire signed [319:0] t_yplusx_out,  // Output t->yplusx
    output wire signed [319:0] t_yminusx_out, // Output t->yminusx
    output wire signed [319:0] t_xy2d_out     // Output t->xy2d
);

    // Instantiate fe_cmov for each field of ge_precomp
    fe_cmov fe_cmov_yplusx (
        .f_in(t_yplusx_in),
        .g(u_yplusx),
        .b(b),
        .f_out(t_yplusx_out)
    );

    fe_cmov fe_cmov_yminusx (
        .f_in(t_yminusx_in),
        .g(u_yminusx),
        .b(b),
        .f_out(t_yminusx_out)
    );

    fe_cmov fe_cmov_xy2d (
        .f_in(t_xy2d_in),
        .g(u_xy2d),
        .b(b),
        .f_out(t_xy2d_out)
    );

endmodule