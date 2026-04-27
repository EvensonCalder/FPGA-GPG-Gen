module fe_invert (
    input clk,                          // Clock input
    input rst,                          // Reset input (active high)
    input start,                        // Start signal
    input signed [319:0] z,             // Input field element
    output reg signed [319:0] out,      // Output (modular inverse of z)
    output reg done                     // Done signal to indicate completion
);
    // State and counter registers
    reg [5:0] state;                    // 6 bits for up to 63 states
    reg [6:0] loop_cnt;                 // 7 bits for up to 100 iterations
    localparam IDLE = 6'd63;
    
    // Intermediate result registers
    reg signed [319:0] t0, t1, t2, t3;

    // Wires for submodule outputs and control
    wire signed [319:0] sq_out, mul_out;
    wire sq_done, mul_done;

    // Control signals for submodules
    reg sq_start, mul_start;
    reg signed [319:0] sq_in, mul_a, mul_b;

    // Instantiate sequential submodules
    fe_sq sq_unit (
        .clk(clk),
        .reset(rst),
        .start(sq_start),
        .f(sq_in),
        .h(sq_out),
        .done(sq_done)
    );
    
    fe_mul mul_unit (
        .clk(clk),
        .reset(rst),
        .start(mul_start),
        .f(mul_a),
        .g(mul_b),
        .h(mul_out),
        .done(mul_done)
    );

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // Reset all registers
            state <= IDLE;
            loop_cnt <= 0;
            t0 <= 0;
            t1 <= 0;
            t2 <= 0;
            t3 <= 0;
            out <= 0;
            sq_in <= 0;
            mul_a <= 0;
            mul_b <= 0;
            sq_start <= 0;
            mul_start <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    loop_cnt <= 0;
                    t0 <= 0;
                    t1 <= 0;
                    t2 <= 0;
                    t3 <= 0;
                    sq_in <= 0;
                    mul_a <= 0;
                    mul_b <= 0;
                    sq_start <= 0;
                    mul_start <= 0;
                    done <= 0; 
                    if (start == 1) begin
                        state <= 0;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                0: begin  // Start first square: z^2
                    sq_in <= z;
                    sq_start <= 1;
                    state <= 1;
                end
                1: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t0 <= sq_out;  // t0 = z^2
                        state <= 2;
                    end
                end
                
                2: begin  // Start second square: t0^2
                    sq_in <= t0;
                    sq_start <= 1;
                    state <= 3;
                end
                3: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t1 <= sq_out;  // t1 = z^4
                        state <= 4;
                    end
                end
                
                4: begin  // Start third square: t1^2
                    sq_in <= t1;
                    sq_start <= 1;
                    state <= 5;
                end
                5: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t1 <= sq_out;  // t1 = z^8
                        state <= 6;
                    end
                end
                
                6: begin  // Start multiplication: z * t1
                    mul_a <= z;
                    mul_b <= t1;
                    mul_start <= 1;
                    state <= 7;
                end
                7: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t1 <= mul_out;  // t1 = z^9
                        state <= 8;
                    end
                end
                
                8: begin  // Start multiplication: t0 * t1
                    mul_a <= t0;
                    mul_b <= t1;
                    mul_start <= 1;
                    state <= 9;
                end
                9: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t0 <= mul_out;  // t0 = z^11
                        state <= 10;
                        loop_cnt <= 0;
                    end
                end
                
                10: begin  // Start square: t0^2
                    sq_in <= t0;
                    sq_start <= 1;
                    state <= 11;
                end
                11: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;  // t2 = z^22
                        state <= 12;
                    end
                end
                
                12: begin  // Start multiplication: t2 * t1
                    mul_a <= t2;
                    mul_b <= t1;
                    mul_start <= 1;
                    state <= 13;
                end
                13: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t1 <= mul_out;  // t1 = z^31
                        state <= 14;
                    end
                end
                
                14: begin  // Start square: t1^2
                    sq_in <= t1;
                    sq_start <= 1;
                    state <= 15;
                end
                15: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;  // t2 = z^62
                        state <= 16;
                        loop_cnt <= 0;
                    end
                end
                
                16: begin  // Start square loop: t2^2 (5 times total)
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 17;
                end
                17: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        if (loop_cnt < 3) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 16;
                        end else begin
                            state <= 18;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                18: begin  // Start multiplication: t2 * t1
                    mul_a <= t2;
                    mul_b <= t1;
                    mul_start <= 1;
                    state <= 19;
                end
                19: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t1 <= mul_out;
                        state <= 20;
                    end
                end
                
                20: begin  // Start square: t1^2
                    sq_in <= t1;
                    sq_start <= 1;
                    state <= 21;
                end
                21: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        state <= 22;
                        loop_cnt <= 0;
                    end
                end
                
                22: begin  // Start square loop: t2^2 (10 times total)
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 23;
                end
                23: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        if (loop_cnt < 8) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 22;
                        end else begin
                            state <= 24;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                24: begin  // Start multiplication: t2 * t1
                    mul_a <= t2;
                    mul_b <= t1;
                    mul_start <= 1;
                    state <= 25;
                end
                25: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t2 <= mul_out;
                        state <= 26;
                    end
                end
                
                26: begin  // Start square: t2^2
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 27;
                end
                27: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t3 <= sq_out;
                        state <= 28;
                        loop_cnt <= 0;
                    end
                end
                
                28: begin  // Start square loop: t3^2 (20 times total)
                    sq_in <= t3;
                    sq_start <= 1;
                    state <= 29;
                end
                29: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t3 <= sq_out;
                        if (loop_cnt < 18) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 28;
                        end else begin
                            state <= 30;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                30: begin  // Start multiplication: t2 * t3
                    mul_a <= t2;
                    mul_b <= t3;
                    mul_start <= 1;
                    state <= 31;
                end
                31: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t2 <= mul_out;
                        state <= 32;
                    end
                end
                
                32: begin  // Start square: t2^2
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 33;
                end
                33: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        state <= 34;
                        loop_cnt <= 0;
                    end
                end
                
                34: begin  // Start square loop: t2^2 (10 times total)
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 35;
                end
                35: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        if (loop_cnt < 8) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 34;
                        end else begin
                            state <= 36;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                36: begin  // Start multiplication: t1 * t2
                    mul_a <= t1;
                    mul_b <= t2;
                    mul_start <= 1;
                    state <= 37;
                end
                37: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t1 <= mul_out;
                        state <= 38;
                    end
                end
                
                38: begin  // Start square: t1^2
                    sq_in <= t1;
                    sq_start <= 1;
                    state <= 39;
                end
                39: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        state <= 40;
                        loop_cnt <= 0;
                    end
                end
                
                40: begin  // Start square loop: t2^2 (50 times total)
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 41;
                end
                41: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        if (loop_cnt < 48) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 40;
                        end else begin
                            state <= 42;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                42: begin  // Start multiplication: t1 * t2
                    mul_a <= t1;
                    mul_b <= t2;
                    mul_start <= 1;
                    state <= 43;
                end
                43: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t2 <= mul_out;
                        state <= 44;
                    end
                end
                
                44: begin  // Start square: t2^2
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 45;
                end
                45: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t3 <= sq_out;
                        state <= 46;
                        loop_cnt <= 0;
                    end
                end
                
                46: begin  // Start square loop: t3^2 (100 times total)
                    sq_in <= t3;
                    sq_start <= 1;
                    state <= 47;
                end
                47: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t3 <= sq_out;
                        if (loop_cnt < 98) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 46;
                        end else begin
                            state <= 48;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                48: begin  // Start multiplication: t2 * t3
                    mul_a <= t2;
                    mul_b <= t3;
                    mul_start <= 1;
                    state <= 49;
                end
                49: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t2 <= mul_out;
                        state <= 50;
                    end
                end
                
                50: begin  // Start square: t2^2
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 51;
                end
                51: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        state <= 52;
                        loop_cnt <= 0;
                    end
                end
                
                52: begin  // Start square loop: t2^2 (50 times total)
                    sq_in <= t2;
                    sq_start <= 1;
                    state <= 53;
                end
                53: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t2 <= sq_out;
                        if (loop_cnt < 48) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 52;
                        end else begin
                            state <= 54;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                54: begin  // Start multiplication: t1 * t2
                    mul_a <= t1;
                    mul_b <= t2;
                    mul_start <= 1;
                    state <= 55;
                end
                55: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        t1 <= mul_out;
                        state <= 56;
                    end
                end
                
                56: begin  // Start square: t1^2
                    sq_in <= t1;
                    sq_start <= 1;
                    state <= 57;
                end
                57: begin  // Wait for square completion
                    sq_start <= 0;
                    if (sq_done) begin
                        t1 <= sq_out;
                        state <= 58;
                        loop_cnt <= 0;
                    end
                end
                
                58: begin  // Start square loop: t1^2 (5 times total)
                    sq_in <= t1;
                    sq_start <= 1;
                    state <= 59;
                end
                59: begin  // Wait for square completion and loop
                    sq_start <= 0;
                    if (sq_done) begin
                        t1 <= sq_out;
                        if (loop_cnt < 3) begin
                            loop_cnt <= loop_cnt + 1;
                            state <= 58;
                        end else begin
                            state <= 60;
                            loop_cnt <= 0;
                        end
                    end
                end
                
                60: begin  // Start final multiplication: t0 * t1
                    mul_a <= t0;
                    mul_b <= t1;
                    mul_start <= 1;
                    state <= 61;
                end
                61: begin  // Wait for multiplication completion
                    mul_start <= 0;
                    if (mul_done) begin
                        out <= mul_out;
                        state <= 62;
                    end
                end
                
                62: begin  // Signal completion
                    done <= 1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 0;
                    sq_start <= 0;
                    mul_start <= 0;
                end
            endcase
        end
    end
endmodule