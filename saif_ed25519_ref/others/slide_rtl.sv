module slide_rtl(
    input clk,
    input rst,
    input start,
    input [255:0] a,
    output reg signed [4:0] r [0:255], // 5-bit signed for -16 to 15
    output reg done
);

localparam IDLE        = 0;
localparam INIT        = 1;
localparam MAIN_LOOP   = 2;
localparam CHECK_RI    = 3;
localparam B_LOOP      = 4;
localparam CHECK_BOUNDS= 5;
localparam CHECK_R_IB  = 6;
localparam COMPARE_ADD = 7;
localparam UPDATE_ADD  = 8;
localparam COMPARE_SUB = 9;
localparam UPDATE_SUB  = 10;
localparam CARRY_LOOP  = 11;
localparam BREAK_CARRY = 12;
localparam INCREMENT_B = 13;
localparam BREAK_B     = 14;
localparam INCREMENT_I = 15;
localparam DONE        = 16;

reg [4:0] ns, cs;
reg [7:0] i;  // 0-255
reg [3:0] b;  // 1-6 (using 4 bits to avoid overflow)
reg [7:0] k;  // carry loop index

// Temporary registers for calculations
reg signed [4:0] temp_ri;
reg signed [4:0] temp_rib;
reg signed [9:0] shifted_rib;
reg signed [9:0] sum;
reg signed [9:0] diff;
reg found_non_zero;

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        cs <= IDLE;
    end else begin
        cs <= ns;
    end
end

always @(*) begin
    ns = cs; // Default: stay in current state
    
    case(cs)
        IDLE: begin
            if(start) ns = INIT;
        end
        
        INIT: begin
            if(i == 255) ns = MAIN_LOOP;
            else ns = INIT;
        end
        
        MAIN_LOOP: ns = CHECK_RI;
        
        CHECK_RI: begin
            if(r[i] != 0) ns = B_LOOP;
            else if(i == 255) ns = DONE;
            else ns = INCREMENT_I;
        end
        
        B_LOOP: ns = CHECK_BOUNDS;
        
        CHECK_BOUNDS: begin
            if((i + b) < 256) ns = CHECK_R_IB;
            else ns = INCREMENT_I;
        end
        
        CHECK_R_IB: begin
            if(r[i + b] != 0) ns = COMPARE_ADD;
            else if(b == 6) ns = INCREMENT_I;
            else ns = INCREMENT_B;
        end
        
        COMPARE_ADD: begin
            if(sum <= 15) ns = UPDATE_ADD;
            else if(diff >= -15) ns = UPDATE_SUB;
            else ns = BREAK_B;
        end
        
        UPDATE_ADD: begin
            if(b == 6) ns = INCREMENT_I;
            else ns = INCREMENT_B;
        end
        
        UPDATE_SUB: ns = CARRY_LOOP;
        
        CARRY_LOOP: begin
            if(found_non_zero || k >= 256) ns = INCREMENT_B;
            else ns = CARRY_LOOP;
        end
        
        BREAK_CARRY: ns = INCREMENT_B;
        
        INCREMENT_B: begin
            if(b == 6) ns = INCREMENT_I;
            else ns = B_LOOP;
        end
        
        BREAK_B: ns = INCREMENT_I;
        
        INCREMENT_I: begin
            if(i == 255) ns = DONE;
            else ns = CHECK_RI;
        end
        
        DONE: ns = IDLE;
        
        default: ns = IDLE;
    endcase
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        done <= 0;
        i <= 0;
        b <= 0;
        k <= 0;
        found_non_zero <= 0;
        
        // Initialize r to zeros
        for (integer idx = 0; idx < 256; idx = idx + 1) begin
            r[idx] <= 5'd0;
        end
    end else begin
        case (cs)
            IDLE: begin
                if (start) begin
                    i <= 0;
                    done <= 0;
                end
            end

            INIT: begin
                // Correct bit extraction: r[i] = 1 & (a[i >> 3] >> (i & 7))
                // Note: In Verilog, a[255:0] is bit-indexed, so we need to extract bits differently
                // For a[i >> 3], get the proper byte, then shift by (i & 7)
                r[i] <= {4'b0000, a[i] & 1'b1};
                if (i == 255) begin
                    i <= 0;
                end else begin
                    i <= i + 1;
                end
            end

            MAIN_LOOP: begin
                b <= 1; // Initialize b to 1 for the outer loop
            end


            B_LOOP: begin
                // Calculate values for the next state
                temp_ri <= r[i];
                temp_rib <= r[i + b];
                shifted_rib <= $signed(r[i + b]) << b;
                sum <= $signed(r[i]) + ($signed(r[i + b]) << b);
                diff <= $signed(r[i]) - ($signed(r[i + b]) << b);
            end

            UPDATE_ADD: begin
                // Update r[i] and r[i+b]
                r[i] <= sum[4:0];
                r[i + b] <= 5'd0;
            end

            UPDATE_SUB: begin
                // Update r[i] and prepare for carry loop
                r[i] <= diff[4:0];
                k <= i + b;
                found_non_zero <= 0;
            end

            CARRY_LOOP: begin
                if (k < 256 && !found_non_zero) begin
                    if (r[k] == 0) begin
                        r[k] <= 5'd1;
                        found_non_zero <= 1;
                    end else begin
                        r[k] <= 5'd0;
                        k <= k + 1;
                    end
                end
            end

            INCREMENT_B: begin
                b <= b + 1;
                found_non_zero <= 0;
            end

            INCREMENT_I: begin
                i <= i + 1;
                b <= 1; // Reset b for the next iteration
            end

            DONE: begin
                done <= 1;
            end
        endcase
    end
end

endmodule