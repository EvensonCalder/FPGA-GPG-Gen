module Reg_File (
    input  logic         clk, 
    input  logic         rst, 
    input  logic         write_en,   // Enable write operation
    input  logic [2:0]   addr,       // Address to select register
    input  logic [511:0] write_data, // Data to be written

    // Register Outputs (Accessible by FSM and Serializer)
    output logic [511:0] REG_A1, // Received Message (64B)
    output logic [511:0] REG_A2, // Received Signature (64B)
    output logic [255:0] REG_A3, // Received Public Key (32B)

    output logic [511:0] REG_B1, // Generated Private Key (64B)
    output logic [255:0] REG_B2, // Generated Public Key (32B)

    output logic [511:0] REG_C1, // Message to be signed (64B)
    output logic [511:0] REG_C2  // Generated Signature (64B)
);

    // Write Logic
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            REG_A1 <= 512'b0;
            REG_A2 <= 512'b0;
            REG_A3 <= 256'b0;
            REG_B1 <= 512'b0;
            REG_B2 <= 256'b0;
            REG_C1 <= 512'b0;
            REG_C2 <= 512'b0;
        end 
        else if (write_en) begin
            case (addr)
                3'b000: REG_A1 <= write_data;
                3'b001: REG_A2 <= write_data;
                3'b010: REG_A3 <= write_data[255:0]; // Only store lower 256 bits
                3'b011: REG_B1 <= write_data;
                3'b100: REG_B2 <= write_data[255:0]; // Only store lower 256 bits
                3'b101: REG_C1 <= write_data;
                3'b110: REG_C2 <= write_data;
            endcase
        end
    end

endmodule
