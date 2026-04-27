module ge_p3_to_p2(
    // Inputs from ge_p3 structure
    input  signed [319:0] p_X,
    input  signed [319:0] p_Y,
    input  signed [319:0] p_Z,
    input  signed [319:0] p_T,
    // Outputs to ge_cached structure
    output signed [319:0] r_X,
    output signed [319:0] r_Y,
    output signed [319:0] r_Z
    
);


  

   // Copy p->Z to r->Z
  fe_copy u_fe_copy1 (
      .f(p_X),
      .h(r_X)
  );

    // Copy p->Z to r->Z
  fe_copy u_fe_copy2 (
      .f(p_Y),
      .h(r_Y)
  );

  // Copy p->Z to r->Z
  fe_copy u_fe_copy3 (
      .f(p_Z),
      .h(r_Z)
  );

  
endmodule
