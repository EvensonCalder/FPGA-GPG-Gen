module fe_pow (
    input clk,                          // Clock input
    input reset,                        // Asynchronous reset (active low)
    input start,                        // Start signal
    input signed [319:0] z,             // Input field element
    output reg signed [319:0] out,      // Output field element
    output reg done                     // Done signal
);
    // State and loop counter
    reg [7:0] state;                    // State register
    reg [6:0] loop_cnt;                 // Loop counter for repeated squarings
    localparam IDLE = 8'd0;

    // Intermediate registers
    reg signed [319:0] t0, t1, t2;

    // Submodule I/O for squaring unit
    reg signed [319:0] sq_in;
    wire signed [319:0] sq_out;
    reg sq_start;
    wire sq_done;
    
    // Submodule I/O for multiplication unit
    reg signed [319:0] mul_a, mul_b;
    wire signed [319:0] mul_out;
    reg mul_start;
    wire mul_done;

    // Instantiate square and multiply units (sequential)
    fe_sq sq_unit (
        .clk(clk),
        .reset(reset),
        .start(sq_start),
        .f(sq_in),
        .h(sq_out),
        .done(sq_done)
    );
    
    fe_mul mul_unit (
        .clk(clk),
        .reset(reset),
        .start(mul_start),
        .f(mul_a),
        .g(mul_b),
        .h(mul_out),
        .done(mul_done)
    );

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            loop_cnt <= 0;
            t0 <= 0; 
            t1 <= 0; 
            t2 <= 0;
            out <= 0;
            sq_in <= 0;
            sq_start <= 0;
            mul_a <= 0; 
            mul_b <= 0;
            mul_start <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    loop_cnt <= 0;
                    sq_start <= 0;
                    mul_start <= 0;
                    if (start) begin
                        state <= 1;
                    end
                end

                // 1) t0 = z^2
                1: begin 
                    sq_in <= z; 
                    sq_start <= 1; 
                    state <= 2; 
                end
                2: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t0 <= sq_out; 
                        state <= 3; 
                    end
                end

                // 2) t1 = t0^(2^2) (2 squarings) - First squaring
                3: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    state <= 4; 
                end
                4: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        state <= 5; 
                    end
                end
                
                // Second squaring
                5: begin 
                    sq_in <= t1; 
                    sq_start <= 1; 
                    state <= 6; 
                end
                6: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        state <= 7; 
                    end
                end

                // 3) t1 = z * t1 (z^9)
                7: begin 
                    mul_a <= z; 
                    mul_b <= t1; 
                    mul_start <= 1; 
                    state <= 8; 
                end
                8: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t1 <= mul_out; 
                        state <= 9; 
                    end
                end

                // 4) t0 = t0 * t1 (z^11)
                9: begin 
                    mul_a <= t0; 
                    mul_b <= t1; 
                    mul_start <= 1; 
                    state <= 10; 
                end
                10: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t0 <= mul_out; 
                        state <= 11; 
                    end
                end

                // 5) t0 = t0^2 (z^22)
                11: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    state <= 12; 
                end
                12: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t0 <= sq_out; 
                        state <= 13; 
                    end
                end

                // 6) t0 = t1 * t0 (z_5_0)
                13: begin 
                    mul_a <= t1; 
                    mul_b <= t0; 
                    mul_start <= 1; 
                    state <= 14; 
                end
                14: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t0 <= mul_out; 
                        state <= 15; 
                    end
                end

                // 7) t1 = t0^(2^5) (5 squarings)
                15: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 16; 
                end
                16: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 4) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 17;
                        end
                    end
                end

                // 8) t0 = t1 * t0 (z_10_0)
                17: begin 
                    mul_a <= t1; 
                    mul_b <= t0; 
                    mul_start <= 1; 
                    state <= 18; 
                end
                18: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t0 <= mul_out; 
                        state <= 19; 
                    end
                end

                // 9) t1 = t0^(2^10) (10 squarings)
                19: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 20; 
                end
                20: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 9) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 21;
                        end
                    end
                end

                // 10) t1 = t1 * t0 (z_20_0)
                21: begin 
                    mul_a <= t1; 
                    mul_b <= t0; 
                    mul_start <= 1; 
                    state <= 22; 
                end
                22: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t1 <= mul_out; 
                        state <= 23; 
                    end
                end

                // 11) t2 = t1^(2^20) (20 squarings)
                23: begin 
                    sq_in <= t1; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 24; 
                end
                24: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t2 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 19) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 25;
                        end
                    end
                end

                // 12) t1 = t2 * t1
                25: begin 
                    mul_a <= t2; 
                    mul_b <= t1; 
                    mul_start <= 1; 
                    state <= 26; 
                end
                26: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t1 <= mul_out; 
                        state <= 27; 
                    end
                end

                // 13) t1 = t1^(2^10) (10 squarings)
                27: begin 
                    sq_in <= t1; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 28; 
                end
                28: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 9) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 29;
                        end
                    end
                end

                // 14) t0 = t1 * t0
                29: begin 
                    mul_a <= t1; 
                    mul_b <= t0; 
                    mul_start <= 1; 
                    state <= 30; 
                end
                30: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t0 <= mul_out; 
                        state <= 31; 
                    end
                end

                // 15) t1 = t0^(2^50) (50 squarings)
                31: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 32; 
                end
                32: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 49) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 33;
                        end
                    end
                end

                // 16) t1 = t1 * t0
                33: begin 
                    mul_a <= t1; 
                    mul_b <= t0; 
                    mul_start <= 1; 
                    state <= 34; 
                end
                34: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t1 <= mul_out; 
                        state <= 35; 
                    end
                end

                // 17) t2 = t1^(2^100) (100 squarings)
                35: begin 
                    sq_in <= t1; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 36; 
                end
                36: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t2 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 99) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 37;
                        end
                    end
                end

                // 18) t1 = t2 * t1
                37: begin 
                    mul_a <= t2; 
                    mul_b <= t1; 
                    mul_start <= 1; 
                    state <= 38; 
                end
                38: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t1 <= mul_out; 
                        state <= 39; 
                    end
                end

                // 19) t1 = t1^(2^50) (50 squarings)
                39: begin 
                    sq_in <= t1; 
                    sq_start <= 1; 
                    loop_cnt <= 0; 
                    state <= 40; 
                end
                40: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t1 <= sq_out; 
                        loop_cnt <= loop_cnt + 1;
                        if (loop_cnt < 49) begin
                            sq_in <= sq_out;
                            sq_start <= 1;
                        end else begin
                            state <= 41;
                        end
                    end
                end

                // 20) t0 = t1 * t0
                41: begin 
                    mul_a <= t1; 
                    mul_b <= t0; 
                    mul_start <= 1; 
                    state <= 42; 
                end
                42: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        t0 <= mul_out; 
                        state <= 43; 
                    end
                end

                // 21) t0 = t0^(2^2) (2 squarings) - First squaring
                43: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    state <= 44; 
                end
                44: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t0 <= sq_out; 
                        state <= 45; 
                    end
                end
                
                // Second squaring
                45: begin 
                    sq_in <= t0; 
                    sq_start <= 1; 
                    state <= 46; 
                end
                46: begin 
                    sq_start <= 0; 
                    if (sq_done) begin
                        t0 <= sq_out; 
                        state <= 47; 
                    end
                end

                // 22) Final multiplication: out = t0 * z
                47: begin 
                    mul_a <= t0; 
                    mul_b <= z; 
                    mul_start <= 1; 
                    state <= 48; 
                end
                48: begin 
                    mul_start <= 0; 
                    if (mul_done) begin
                        out <= mul_out; 
                        done <= 1; 
                        state <= IDLE; 
                    end
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