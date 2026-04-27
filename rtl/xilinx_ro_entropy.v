`timescale 1ns / 1ps

// One odd-inverter ring oscillator entropy cell.
// Vivado needs the matching XDC ALLOW_COMBINATORIAL_LOOPS constraint.
(* keep_hierarchy = "yes", dont_touch = "yes" *)
module xilinx_ro_entropy #(
    parameter integer STAGES = 7
) (
    input  wire enable,
    output wire ro_out
);
    (* keep = "true", dont_touch = "true" *) wire [STAGES-1:0] chain;

    assign chain[0] = enable ? ~chain[STAGES-1] : 1'b0;

    genvar i;
    generate
        for (i = 1; i < STAGES; i = i + 1) begin : inv_gen
            assign chain[i] = ~chain[i-1];
        end
    endgenerate

    assign ro_out = chain[STAGES-1];
endmodule
