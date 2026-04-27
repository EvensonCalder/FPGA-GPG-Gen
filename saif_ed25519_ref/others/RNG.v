module LFSR_256bit (
    input clk,         // Clock signal
    input rst,         // Reset signal (active low)
    output reg [255:0] random_num  // 256-bit LFSR output
);

    always @(posedge clk or negedge rst) begin
        if (!rst)
            random_num <= 256'hA5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5; // Seed (Non-zero)
        else begin
            // Compute new bit: XOR of selected taps
            random_num <= {random_num[254:0], 
                           random_num[255] ^ random_num[251] ^ random_num[249] ^ random_num[245]};
        end
    end

endmodule
