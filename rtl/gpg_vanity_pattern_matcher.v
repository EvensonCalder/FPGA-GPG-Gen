`timescale 1ns / 1ps

module gpg_vanity_pattern_matcher #(
    parameter DEBUG_ACCEPT_ALL = 1'b0
) (
    input  wire [159:0] fingerprint,
    output reg          hit,
    output reg  [3:0]   class_id
);
    wire [31:0] prefix = fingerprint[159:128];
    wire [31:0] suffix = fingerprint[31:0];

    wire prefix_same8 =
        (prefix[31:28] == prefix[27:24]) &&
        (prefix[31:28] == prefix[23:20]) &&
        (prefix[31:28] == prefix[19:16]) &&
        (prefix[31:28] == prefix[15:12]) &&
        (prefix[31:28] == prefix[11:8])  &&
        (prefix[31:28] == prefix[7:4])   &&
        (prefix[31:28] == prefix[3:0]);

    wire suffix_same8 =
        (suffix[31:28] == suffix[27:24]) &&
        (suffix[31:28] == suffix[23:20]) &&
        (suffix[31:28] == suffix[19:16]) &&
        (suffix[31:28] == suffix[15:12]) &&
        (suffix[31:28] == suffix[11:8])  &&
        (suffix[31:28] == suffix[7:4])   &&
        (suffix[31:28] == suffix[3:0]);

    always @* begin
        if (DEBUG_ACCEPT_ALL) begin
            hit = 1'b1;
            class_id = 4'h0;
        end else if (suffix_same8) begin
            hit = 1'b1;
            class_id = 4'h0;
        end else if (prefix_same8) begin
            hit = 1'b1;
            class_id = 4'h1;
        end else begin
            hit = 1'b0;
            class_id = 4'h0;
        end
    end
endmodule
