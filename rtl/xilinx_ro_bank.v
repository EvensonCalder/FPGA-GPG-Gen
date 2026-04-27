`timescale 1ns / 1ps

(* keep_hierarchy = "yes", dont_touch = "yes" *)
module xilinx_ro_bank #(
    parameter integer RO_COUNT = 16
) (
    input  wire enable,
    output wire [RO_COUNT-1:0] ro_bits
);
    genvar i;
    generate
        for (i = 0; i < RO_COUNT; i = i + 1) begin : ro_gen
            localparam integer RO_STAGES = 5 + ((i % 4) * 2);

            xilinx_ro_entropy #(
                .STAGES(RO_STAGES)
            ) ro_inst (
                .enable(enable),
                .ro_out(ro_bits[i])
            );
        end
    endgenerate
endmodule
