module ge_p2_dbl(
    input clk,
    input reset,
    input start,
    output reg done,
    
    // Input port structure p (ge_p2)
    input signed [319:0] p_X,
    input signed [319:0] p_Y,
    input signed [319:0] p_Z,
    
    // Output port structure r (ge_p1p1)
    output reg signed [319:0] r_X,
    output reg signed [319:0] r_Y,
    output reg signed [319:0] r_Z,
    output reg signed [319:0] r_T
);

    // State machine states
    typedef enum logic [4:0] {
        IDLE,
        CALC_XX_START,
        CALC_XX_WAIT,
        CALC_YY_START,
        CALC_YY_WAIT,
        CALC_B_START,
        CALC_B_WAIT,
        CALC_A,
        CALC_AA_START,
        CALC_AA_WAIT,
        CALC_RY_RZ,
        CALC_SETTLE,
        CALC_RX,
        CALC_RT,
        DONE_STATE
    } state_t;
    
    state_t current_state, next_state;

    // Intermediate registers
    reg signed [319:0] XX, YY, B, A, AA;
    
    // Control signals for multiplexers
    reg [1:0] add_sel, sub_sel, sq_sel, sq2_sel;
    reg sq_start, sq2_start;
    wire sq_done, sq2_done;
    
    // Arithmetic unit inputs/outputs
    reg signed [319:0] add_f, add_g, add_h;
    reg signed [319:0] sub_f, sub_g, sub_h;
    reg signed [319:0] sq_f, sq_h;
    reg signed [319:0] sq2_f, sq2_h;
    
    // Single instance of each arithmetic unit
    fe_add add_unit (
        .f(add_f), 
        .g(add_g), 
        .h(add_h)
    );
    
    fe_sub sub_unit (
        .f(sub_f), 
        .g(sub_g), 
        .h(sub_h)
    );
    
    // Sequential squaring unit with control signals
    fe_sq sq_unit (
        .clk(clk),
        .reset(reset),
        .start(sq_start),
        .done(sq_done),
        .f(sq_f), 
        .h(sq_h)
    );
    
    // Sequential double squaring unit with control signals  
    fe_sq2 sq2_unit (
        .clk(clk),
        .reset(reset),
        .start(sq2_start),
        .done(sq2_done),
        .f(sq2_f), 
        .h(sq2_h)
    );
    
    // Input multiplexers for add unit
    always_comb begin
        case (add_sel)
            2'b00: begin // A = p_X + p_Y
                add_f = p_X;
                add_g = p_Y;
            end
            2'b01: begin // r_Y = YY + XX
                add_f = YY;
                add_g = XX;
            end
            default: begin
                add_f = 320'b0;
                add_g = 320'b0;
            end
        endcase
    end
    
    // Input multiplexers for sub unit
    always_comb begin
        case (sub_sel)
            2'b00: begin // r_Z = YY - XX
                sub_f = YY;
                sub_g = XX;
            end
            2'b01: begin // r_X = AA - r_Y
                sub_f = AA;
                sub_g = r_Y;
            end
            2'b10: begin // r_T = B - r_Z
                sub_f = B;
                sub_g = r_Z;
            end
            default: begin
                sub_f = 320'b0;
                sub_g = 320'b0;
            end
        endcase
    end
    
    // Input multiplexers for sq unit
    always_comb begin
        case (sq_sel)
            2'b00: begin // XX = p_X^2
                sq_f = p_X;
            end
            2'b01: begin // YY = p_Y^2
                sq_f = p_Y;
            end
            2'b10: begin // AA = A^2
                sq_f = A;
            end
            default: begin
                sq_f = 320'b0;
            end
        endcase
    end
    
    // Input multiplexers for sq2 unit
    always_comb begin
        case (sq2_sel)
            2'b00: begin // B = 2*(p_Z^2)
                sq2_f = p_Z;
            end
            default: begin
                sq2_f = 320'b0;
            end
        endcase
    end
    // State machine sequential logic
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            current_state <= IDLE;
            XX <= 320'b0;
            YY <= 320'b0;
            B <= 320'b0;
            A <= 320'b0;
            AA <= 320'b0;
            r_X <= 320'b0;
            r_Y <= 320'b0;
            r_Z <= 320'b0;
            r_T <= 320'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Register intermediate results based on current state
            case (current_state)
                CALC_XX_WAIT: begin
                    if (sq_done) begin
                        XX <= sq_h;    // XX = p_X^2
                    end
                end
                CALC_YY_WAIT: begin
                    if (sq_done) begin
                        YY <= sq_h;    // YY = p_Y^2
                    end
                end
                CALC_B_WAIT: begin
                    if (sq2_done) begin
                        B <= sq2_h;   // B = 2*(p_Z^2)
                    end
                end
                CALC_A: begin
                    A <= add_h;    // A = p_X + p_Y
                end
                CALC_AA_WAIT: begin
                    if (sq_done) begin
                        AA <= sq_h;   // AA = A^2
                    end
                end
                CALC_RY_RZ: begin
                    r_Y <= add_h;  // r_Y = YY + XX
                    r_Z <= sub_h;  // r_Z = YY - XX
                end
                CALC_SETTLE: begin
                    // Values r_Y and r_Z are now stable, no register updates
                end
                CALC_RX: begin
                    r_X <= sub_h;  // r_X = AA - r_Y
                end
                CALC_RT: begin
                        r_T <= sub_h;  // r_T = B - r_Z                    
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // State machine combinational logic
    always_comb begin
        next_state = current_state;
        add_sel = 2'b00;
        sub_sel = 2'b00;
        sq_sel = 2'b00;
        sq2_sel = 2'b00;
        sq_start = 1'b0;
        sq2_start = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_XX_START;
                end
            end
            
            CALC_XX_START: begin
                sq_sel = 2'b00; // XX = p_X^2
                sq_start = 1'b1;
                next_state = CALC_XX_WAIT;
            end
            
            CALC_XX_WAIT: begin
                sq_sel = 2'b00; // Keep inputs stable
                if (sq_done) begin
                    next_state = CALC_YY_START;
                end
            end
            
            CALC_YY_START: begin
                sq_sel = 2'b01; // YY = p_Y^2
                sq_start = 1'b1;
                next_state = CALC_YY_WAIT;
            end
            
            CALC_YY_WAIT: begin
                sq_sel = 2'b01; // Keep inputs stable
                if (sq_done) begin
                    next_state = CALC_B_START;
                end
            end
            
            CALC_B_START: begin
                sq2_sel = 2'b00; // B = 2*(p_Z^2)
                sq2_start = 1'b1;
                next_state = CALC_B_WAIT;
            end
            
            CALC_B_WAIT: begin
                sq2_sel = 2'b00; // Keep inputs stable
                if (sq2_done) begin
                    next_state = CALC_A;
                end
            end
            
            CALC_A: begin
                add_sel = 2'b00; // A = p_X + p_Y
                next_state = CALC_AA_START;
            end
            
            CALC_AA_START: begin
                sq_sel = 2'b10; // AA = A^2
                sq_start = 1'b1;
                next_state = CALC_AA_WAIT;
            end
            
            CALC_AA_WAIT: begin
                sq_sel = 2'b10; // Keep inputs stable
                if (sq_done) begin
                    next_state = CALC_RY_RZ;
                end
            end
            
            CALC_RY_RZ: begin
                add_sel = 2'b01; // r_Y = YY + XX
                sub_sel = 2'b00; // r_Z = YY - XX
                next_state = CALC_SETTLE;
            end
            
            CALC_SETTLE: begin
                // Give r_Y and r_Z one cycle to settle
                next_state = CALC_RX;
            end
            
            CALC_RX: begin
                sub_sel = 2'b01; // r_X = AA - r_Y
                next_state = CALC_RT;
            end
            
            CALC_RT: begin
                sub_sel = 2'b10; // r_T = B - r_Z
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule