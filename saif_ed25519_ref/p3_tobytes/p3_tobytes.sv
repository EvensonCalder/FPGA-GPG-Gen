module ge_p3_tobytes(
    input  [319:0] X,  // 256-bit X coordinate
    input  [319:0] Y,  // 256-bit Y coordinate
    input  [319:0] Z,  // 256-bit Z coordinate
    input clk, rst, start,
    output reg done,
    output reg [7:0] s[31:0]   // 256-bit compressed output
);
    // State machine parameters
    typedef enum logic [3:0] {
        IDLE,
        START_INV,
        WAIT_INV,
        START_MUL_X,
        WAIT_MUL_X,
        START_MUL_Y,
        WAIT_MUL_Y,
        START_SIGN_BYTES,
        WAIT_SIGN_BYTES,
        START_Y_BYTES,
        WAIT_Y_BYTES,
        FINISH
    } state_t;

    state_t state;
    reg [319:0] recip;        // 1/Z (from inversion module)
    reg [319:0] x_norm;       // Normalized X
    reg [319:0] y_norm;       // Normalized Y
    reg inv_start;             // Start signal for inversion
    reg mul_start;             // Start signal for multiplier
    reg [319:0] mul_in_f;     // Multiplier operand f
    reg [319:0] mul_in_g;     // Multiplier operand g
    wire [319:0] mul_out;     // Multiplier result
    wire done_inv;            // Inversion done flag
    wire mul_done;            // Multiplier done flag
    wire mul_ready;
    reg is_negative;          // Sign of x-coordinate
    reg bytes_start;
    reg [319:0] bytes_in;
    wire bytes_done;
    wire [7:0] s_comp[31:0]; // Compressed byte output (before sign adjustment)

    // Instantiate inversion module
    fe_invert fe_inv (
        .z(Z),
        .start(inv_start),
        .clk(clk),
        .rst(rst),
        .post_mul_start(mul_start),
        .post_mul_a(mul_in_f),
        .post_mul_b(mul_in_g),
        .post_mul_ready(mul_ready),
        .post_mul_out(mul_out),
        .post_mul_done(mul_done),
        .done(done_inv),
        .out(recip)
    );

    fe_tobytes_seq fe_bytes (
        .clk(clk),
        .reset(rst),
        .start(bytes_start),
        .h(bytes_in),
        .s(s_comp),
        .busy(),
        .done(bytes_done)
    );

    // FSM controller
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            done <= 0;
            inv_start <= 0;
            mul_start <= 0;
            bytes_start <= 0;
            bytes_in <= 0;
            is_negative <= 0;
            mul_in_f <= 0;
            mul_in_g <= 0;
            x_norm <= 0;
            y_norm <= 0;
            for (int i = 0; i < 32; i++) s[i] <= 0;
        end else begin
            // Default assignments
            inv_start <= 0;
            mul_start <= 0;
            bytes_start <= 0;
            done <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        inv_start <= 1;  // Start inversion
                        state <= START_INV;
                    end
                end

                START_INV: begin
                    state <= WAIT_INV;
                end

                WAIT_INV: begin
                    if (done_inv) begin
                        // Prepare first multiplication (X * 1/Z)
                        mul_in_f <= X;
                        mul_in_g <= recip;
                        mul_start <= 1;
                        state <= START_MUL_X;
                    end
                end

                START_MUL_X: begin
                    state <= WAIT_MUL_X;
                end

                WAIT_MUL_X: begin
                    if (mul_done) begin
                        x_norm <= mul_out;  // Store normalized X
                        // Prepare second multiplication (Y * 1/Z)
                        mul_in_f <= Y;
                        mul_in_g <= recip;
                        mul_start <= 1;
                        state <= START_MUL_Y;
                    end
                end

                START_MUL_Y: begin
                    state <= WAIT_MUL_Y;
                end

                WAIT_MUL_Y: begin
                    if (mul_done) begin
                        y_norm <= mul_out;  // Store normalized Y
                        bytes_in <= x_norm;
                        bytes_start <= 1;
                        state <= START_SIGN_BYTES;
                    end
                end

                START_SIGN_BYTES: begin
                    state <= WAIT_SIGN_BYTES;
                end

                WAIT_SIGN_BYTES: begin
                    if (bytes_done) begin
                        is_negative <= s_comp[0][0];
                        bytes_in <= y_norm;
                        bytes_start <= 1;
                        state <= START_Y_BYTES;
                    end
                end

                START_Y_BYTES: begin
                    state <= WAIT_Y_BYTES;
                end

                WAIT_Y_BYTES: begin
                    if (bytes_done) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Update output with sign adjustment
                    for (int i = 0; i < 32; i++) 
                        s[i] <= s_comp[i];
                    s[31][7] <= s_comp[31][7] ^ is_negative;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
