module decompose (
    input  logic [255:0] a,               // Input: 256-bit vector (32 bytes)
    output logic signed [7:0] e [0:63]     // Output: 64 elements of 8-bit values
);

    always_comb begin
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            e[2*i]     = a[8*i +: 4];    // Lower nibble (bits 0-3)
            e[2*i + 1] = a[8*i+4 +: 4];  // Upper nibble (bits 4-7)
        end
    end

endmodule
