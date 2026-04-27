module ge_p3_dbl(
    input  clk,
    input  reset,
    input  start,
    output done,
    // Input ge_p3 point
    input  signed [319:0] p_X,
    input  signed [319:0] p_Y,
    input  signed [319:0] p_Z,
    input  signed [319:0] p_T,
    // Output ge_p1p1 point
    output signed [319:0] r_X,
    output signed [319:0] r_Y,
    output signed [319:0] r_Z,
    output signed [319:0] r_T
);

  // Internal wire to hold the intermediate ge_p2 point.
  wire [319:0] q_X, q_Y, q_Z;
  
  // Internal signals for sequential control
  wire p2_dbl_done;

  // Convert ge_p3 to ge_p2 (assuming this remains combinational).
  ge_p3_to_p2 u_ge_p3_to_p2 (
      .p_X(p_X),
      .p_Y(p_Y),
      .p_Z(p_Z),
      .p_T(p_T),
      .r_X(q_X),
      .r_Y(q_Y),
      .r_Z(q_Z)
  );

  // Double the ge_p2 point to obtain a ge_p1p1 result (now sequential).
  ge_p2_dbl u_ge_p2_dbl (
      .clk(clk),
      .reset(reset),
      .start(start),
      .done(p2_dbl_done),
      .p_X(q_X),
      .p_Y(q_Y),
      .p_Z(q_Z),
      .r_X(r_X),
      .r_Y(r_Y),
      .r_Z(r_Z),
      .r_T(r_T)
  );

  // The top module is done when the ge_p2_dbl operation is complete
  assign done = p2_dbl_done;

endmodule