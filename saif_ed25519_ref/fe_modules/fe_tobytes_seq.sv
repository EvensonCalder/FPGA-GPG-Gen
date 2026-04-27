module fe_tobytes_seq (
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  start,
    input  wire signed [319:0]   h,
    output logic [7:0]           s [31:0],
    output logic                 busy,
    output logic                 done
);
    typedef enum logic [4:0] {
        IDLE,
        Q0, Q1, Q2, Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q10,
        ADD_Q,
        CARRY0, CARRY1, CARRY2, CARRY3, CARRY4_ST,
        CARRY5, CARRY6, CARRY7, CARRY8, CARRY9,
        PACK,
        DONE_ST
    } state_t;

    state_t state;
    logic signed [31:0] h0, h1, h2, h3, h4, h5, h6, h7, h8, h9;
    logic signed [31:0] q;

    assign busy = (state != IDLE) && (state != DONE_ST);

    function automatic signed [31:0] shl32;
        input signed [31:0] sig;
        input [5:0] lshift;
        reg [31:0] unsigned_s;
        begin
            unsigned_s = sig;
            shl32 = unsigned_s << lshift;
        end
    endfunction

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            h0 <= 0; h1 <= 0; h2 <= 0; h3 <= 0; h4 <= 0;
            h5 <= 0; h6 <= 0; h7 <= 0; h8 <= 0; h9 <= 0;
            q <= 0;
            done <= 1'b0;
            for (int i = 0; i < 32; i = i + 1)
                s[i] <= 8'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        h0 <= h[31:0];
                        h1 <= h[63:32];
                        h2 <= h[95:64];
                        h3 <= h[127:96];
                        h4 <= h[159:128];
                        h5 <= h[191:160];
                        h6 <= h[223:192];
                        h7 <= h[255:224];
                        h8 <= h[287:256];
                        h9 <= h[319:288];
                        state <= Q0;
                    end
                end

                Q0: begin q <= (19 * h9 + (1 << 24)) >>> 25; state <= Q1; end
                Q1: begin q <= (h0 + q) >>> 26; state <= Q2; end
                Q2: begin q <= (h1 + q) >>> 25; state <= Q3; end
                Q3: begin q <= (h2 + q) >>> 26; state <= Q4; end
                Q4: begin q <= (h3 + q) >>> 25; state <= Q5; end
                Q5: begin q <= (h4 + q) >>> 26; state <= Q6; end
                Q6: begin q <= (h5 + q) >>> 25; state <= Q7; end
                Q7: begin q <= (h6 + q) >>> 26; state <= Q8; end
                Q8: begin q <= (h7 + q) >>> 25; state <= Q9; end
                Q9: begin q <= (h8 + q) >>> 26; state <= Q10; end
                Q10: begin q <= (h9 + q) >>> 25; state <= ADD_Q; end

                ADD_Q: begin
                    h0 <= h0 + 19 * q;
                    state <= CARRY0;
                end

                CARRY0: begin
                    h1 <= h1 + (h0 >>> 26);
                    h0 <= h0 - shl32(h0 >>> 26, 6'd26);
                    state <= CARRY1;
                end
                CARRY1: begin
                    h2 <= h2 + (h1 >>> 25);
                    h1 <= h1 - shl32(h1 >>> 25, 6'd25);
                    state <= CARRY2;
                end
                CARRY2: begin
                    h3 <= h3 + (h2 >>> 26);
                    h2 <= h2 - shl32(h2 >>> 26, 6'd26);
                    state <= CARRY3;
                end
                CARRY3: begin
                    h4 <= h4 + (h3 >>> 25);
                    h3 <= h3 - shl32(h3 >>> 25, 6'd25);
                    state <= CARRY4_ST;
                end
                CARRY4_ST: begin
                    h5 <= h5 + (h4 >>> 26);
                    h4 <= h4 - shl32(h4 >>> 26, 6'd26);
                    state <= CARRY5;
                end
                CARRY5: begin
                    h6 <= h6 + (h5 >>> 25);
                    h5 <= h5 - shl32(h5 >>> 25, 6'd25);
                    state <= CARRY6;
                end
                CARRY6: begin
                    h7 <= h7 + (h6 >>> 26);
                    h6 <= h6 - shl32(h6 >>> 26, 6'd26);
                    state <= CARRY7;
                end
                CARRY7: begin
                    h8 <= h8 + (h7 >>> 25);
                    h7 <= h7 - shl32(h7 >>> 25, 6'd25);
                    state <= CARRY8;
                end
                CARRY8: begin
                    h9 <= h9 + (h8 >>> 26);
                    h8 <= h8 - shl32(h8 >>> 26, 6'd26);
                    state <= CARRY9;
                end
                CARRY9: begin
                    h9 <= h9 - shl32(h9 >>> 25, 6'd25);
                    state <= PACK;
                end

                PACK: begin
                    s[0]  <= h0 >> 0;
                    s[1]  <= h0 >> 8;
                    s[2]  <= h0 >> 16;
                    s[3]  <= (h0 >> 24) | shl32(h1, 6'd2);
                    s[4]  <= h1 >> 6;
                    s[5]  <= h1 >> 14;
                    s[6]  <= (h1 >> 22) | shl32(h2, 6'd3);
                    s[7]  <= h2 >> 5;
                    s[8]  <= h2 >> 13;
                    s[9]  <= (h2 >> 21) | shl32(h3, 6'd5);
                    s[10] <= h3 >> 3;
                    s[11] <= h3 >> 11;
                    s[12] <= (h3 >> 19) | shl32(h4, 6'd6);
                    s[13] <= h4 >> 2;
                    s[14] <= h4 >> 10;
                    s[15] <= h4 >> 18;
                    s[16] <= h5 >> 0;
                    s[17] <= h5 >> 8;
                    s[18] <= h5 >> 16;
                    s[19] <= (h5 >> 24) | shl32(h6, 6'd1);
                    s[20] <= h6 >> 7;
                    s[21] <= h6 >> 15;
                    s[22] <= (h6 >> 23) | shl32(h7, 6'd3);
                    s[23] <= h7 >> 5;
                    s[24] <= h7 >> 13;
                    s[25] <= (h7 >> 21) | shl32(h8, 6'd4);
                    s[26] <= h8 >> 4;
                    s[27] <= h8 >> 12;
                    s[28] <= (h8 >> 20) | shl32(h9, 6'd6);
                    s[29] <= h9 >> 2;
                    s[30] <= h9 >> 10;
                    s[31] <= h9 >> 18;
                    state <= DONE_ST;
                end

                DONE_ST: begin
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
