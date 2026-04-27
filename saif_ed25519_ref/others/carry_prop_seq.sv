module carry_prop_seq (
    input  wire logic              clk,
    input  wire logic              reset,
    input  wire logic              start,
    input  wire logic signed [511:0] e_in,
    output      logic signed [511:0] e_out,
    output      logic              busy,
    output      logic              done
);
    localparam logic [1:0] IDLE = 2'd0;
    localparam logic [1:0] RUN  = 2'd1;
    localparam logic [1:0] PACK = 2'd2;
    localparam logic [1:0] DONE = 2'd3;

    logic [1:0] state;
    logic [5:0] idx;
    logic signed [7:0] carry;
    logic signed [7:0] e_temp [0:63];
    logic signed [7:0] current_sum;
    logic signed [7:0] next_carry;
    logic signed [7:0] reduced_value;

    integer i;

    assign busy = (state == RUN) || (state == PACK);

    always_comb begin
        current_sum = e_temp[idx] + carry;
        next_carry = (current_sum + 8'sd8) >>> 4;
        reduced_value = current_sum - (next_carry <<< 4);
    end

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            idx <= 6'd0;
            carry <= 8'sd0;
            e_out <= 512'sd0;
            done <= 1'b0;
            for (i = 0; i < 64; i = i + 1)
                e_temp[i] <= 8'sd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    idx <= 6'd0;
                    carry <= 8'sd0;
                    if (start) begin
                        for (i = 0; i < 64; i = i + 1)
                            e_temp[i] <= e_in[511 - 8*i -: 8];
                        state <= RUN;
                    end
                end

                RUN: begin
                    if (idx == 6'd63) begin
                        e_temp[63] <= current_sum[7:0];
                        state <= PACK;
                    end else begin
                        e_temp[idx] <= reduced_value[7:0];
                        carry <= next_carry;
                        idx <= idx + 1'b1;
                    end
                end

                PACK: begin
                    for (i = 0; i < 64; i = i + 1)
                        e_out[511 - 8*i -: 8] <= e_temp[i];
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
