module SHA512_PADDING (
    input  [1023:0] message,   // 128-byte input message (LSBs contain valid bytes for mode 0/1)
    input  [1:0]    mode,      // 0:32 bytes, 1:96 bytes, default:128 bytes
    output reg [1023:0] block1, // first 1024-bit padded block
    output reg [1023:0] block2, // second 1024-bit padded block (only used for mode 2)
    output reg        block2_valid // high when a second block is present (mode==2)
);

always @(*) begin
    case (mode)
        // Case 0 (32 Bytes input)
        // Padded block: { message, 8'h80, 632'b0, 64'd0, 64'd256 }
        2'b00 : begin
            block1       = { message[255:0], 8'h80, 632'b0, 64'd0, 64'd256 };
            block2       = 1024'b0;
            block2_valid = 1'b0;
        end
        // Case 1 (96 Bytes input)
        // Padded block: { message, 8'h80, 120'b0, 64'd0, 64'd768 }
        2'b01 : begin
            block1       = { message[767:0], 8'h80, 120'b0, 64'd0, 64'd768 };
            block2       = 1024'b0;
            block2_valid = 1'b0;
        end
        // Case 2 (128 Bytes input)
        // Here the first block is the full message and the second block is:
        // { 8'h80, 888'b0, 64'd0, 64'd1024 }
        default : begin
            block1       = message;
            block2       = { 8'h80, 888'b0, 64'd0, 64'd1024 };
            block2_valid = 1'b1;
        end
    endcase
end

endmodule
