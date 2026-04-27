

module carry_prop (
    input wire logic signed [511:0] e_in,  // Packed input: 64 elements of 8-bit signed values
    output logic signed [511:0] e_out      // Packed output: 64 elements of 8-bit signed values
);
    // Temporary arrays and variables
    logic signed [7:0] carry;
    logic signed [7:0] e_temp [0:63];  // Unpacked temporary array for computation
    logic signed [7:0] shl_result;

    // Instantiate SHL8 module
    SHL8 #(
        .WIDTH(8)
    ) shl8_inst (
        .s(carry),
        .lshift(5'd4),
        .shl_out(shl_result)
    );

    always_comb begin
        integer i;
        carry = 8'sd0;
        
        // Unpack e_in into e_temp
        for (i = 0; i < 64; i = i + 1) begin
            e_temp[i] = e_in[511 - 8*i -: 8];    // Extract 8-bit element (MSB to LSB)
        end
        
        // Apply carry propagation algorithm exactly like C model
        for (i = 0; i < 63; i = i + 1) begin
            e_temp[i] = e_temp[i] + carry;       // Add previous carry
            carry = (e_temp[i] + 8'sd8) >>> 4;   // New carry: (e[i] + 8) >> 4 (arithmetic right shift)
            e_temp[i] = e_temp[i] - (carry << 4); // Subtract carry << 4 (equivalent to SHL8(carry, 4))
        end
        
        // Handle the last element
        e_temp[63] = e_temp[63] + carry;
        
        // Pack e_temp back into e_out
        for (i = 0; i < 64; i = i + 1) begin
            e_out[511 - 8*i -: 8] = e_temp[i];  // Pack back in MSB-to-LSB order
        end
    end
endmodule