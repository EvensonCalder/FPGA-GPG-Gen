module muladd_serial #
(
    parameter WIDTH = 256
)
(
    input  wire                  clk,
    input  wire                  rst,       // sync-active‐high reset
    input  wire                  start,     // pulse to launch operation
    input  wire [WIDTH-1:0]      A,         // multiplicand
    input  wire [WIDTH-1:0]      B,         // multiplier
    input  wire [WIDTH-1:0]      C,         // addend
    output reg  [2*WIDTH-1:0]    out,       // result = A*B + C
    output reg                   done       // pulses when out is valid
);

    // State machine
    localparam IDLE  = 2'd0,
               MUL   = 2'd1,
               ADD   = 2'd2,
               FIN   = 2'd3;
    reg [1:0]              state, next_state;

    // Shift-and-add registers
    reg [WIDTH-1:0]        mult_reg;      // holds shifting multiplier
    reg [2*WIDTH-1:0]      acc_reg;       // partial product accumulator
    reg [2*WIDTH-1:0]      a_shift;       // shifted multiplicand
    reg [8:0]              bit_cnt;       // counts 0…WIDTH

    // State register
    always @(posedge clk) begin
        if (!rst) begin
            state    <= IDLE;
            done     <= 1'b0;
        end else begin
            state    <= next_state;
            // pulse done for one cycle in FIN
            done     <= (state == FIN);
        end
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = MUL;
            MUL:  if (bit_cnt == WIDTH) next_state = ADD;
            ADD:  next_state = FIN;
            FIN:  next_state = IDLE;
        endcase
    end

    // Data path
    always @(posedge clk) begin
        if (!rst) begin
            bit_cnt   <= 0;
            acc_reg   <= 0;
            a_shift   <= 0;
            mult_reg  <= 0;
            out       <= 0;
        end else begin
            case (state)
                IDLE: begin
                    bit_cnt <= 0;
                    if (start) begin
                        // load inputs
                        acc_reg  <= { {(WIDTH){1'b0}}, {(WIDTH){1'b0}} }; 
                        a_shift  <= { {(WIDTH){1'b0}}, A };           // align A at LSB of 2W
                        mult_reg <= B;
                    end
                end
                MUL: begin
                    // each cycle: if LSB of multiplier=1, add shifted A
                    if (mult_reg[0])
                        acc_reg <= acc_reg + a_shift;
                    // shift multiplicand left, multiplier right
                    a_shift  <= a_shift << 1;
                    mult_reg <= mult_reg >> 1;
                    bit_cnt  <= bit_cnt + 1;
                end
                ADD: begin
                    // add C to lower half of accumulator
                    acc_reg <= acc_reg + {{WIDTH{1'b0}}, C};
                end
                FIN: begin
                    out  <= acc_reg;
                end
            endcase
        end
    end

endmodule
