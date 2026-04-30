`timescale 1ns / 1ps

module openpgp_v4_ed25519_fingerprint (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [31:0]  timestamp,
    input  logic [255:0] public_key,
    output logic         busy,
    output logic         done,
    output logic [159:0] fingerprint
);
    localparam logic [31:0] H0_INIT = 32'h67452301;
    localparam logic [31:0] H1_INIT = 32'hefcdab89;
    localparam logic [31:0] H2_INIT = 32'h98badcfe;
    localparam logic [31:0] H3_INIT = 32'h10325476;
    localparam logic [31:0] H4_INIT = 32'hc3d2e1f0;

    typedef enum logic [1:0] {
        ST_IDLE = 2'd0,
        ST_RUN  = 2'd1,
        ST_DONE = 2'd2
    } state_t;

    state_t state;
    logic [6:0] round;
    logic [31:0] a, b, c, d, e;
    logic [31:0] w [0:79];
    logic [511:0] init_block;

    assign busy = (state != ST_IDLE);

    function automatic [31:0] rol32;
        input [31:0] x;
        input [4:0] n;
        begin
            rol32 = (x << n) | (x >> (32 - n));
        end
    endfunction

    function automatic [7:0] pk_byte;
        input [255:0] pk;
        input integer idx;
        begin
            pk_byte = pk[idx * 8 +: 8];
        end
    endfunction

    function automatic [7:0] msg_byte;
        input integer idx;
        input [31:0] ts;
        input [255:0] pk;
        begin
            case (idx)
                0:  msg_byte = 8'h99;
                1:  msg_byte = 8'h00;
                2:  msg_byte = 8'h33;
                3:  msg_byte = 8'h04;
                4:  msg_byte = ts[31:24];
                5:  msg_byte = ts[23:16];
                6:  msg_byte = ts[15:8];
                7:  msg_byte = ts[7:0];
                8:  msg_byte = 8'h16;
                9:  msg_byte = 8'h09;
                10: msg_byte = 8'h2b;
                11: msg_byte = 8'h06;
                12: msg_byte = 8'h01;
                13: msg_byte = 8'h04;
                14: msg_byte = 8'h01;
                15: msg_byte = 8'hda;
                16: msg_byte = 8'h47;
                17: msg_byte = 8'h0f;
                18: msg_byte = 8'h01;
                19: msg_byte = 8'h01;
                20: msg_byte = 8'h07;
                21: msg_byte = 8'h40;
                22: msg_byte = pk_byte(pk, 0);
                23: msg_byte = pk_byte(pk, 1);
                24: msg_byte = pk_byte(pk, 2);
                25: msg_byte = pk_byte(pk, 3);
                26: msg_byte = pk_byte(pk, 4);
                27: msg_byte = pk_byte(pk, 5);
                28: msg_byte = pk_byte(pk, 6);
                29: msg_byte = pk_byte(pk, 7);
                30: msg_byte = pk_byte(pk, 8);
                31: msg_byte = pk_byte(pk, 9);
                32: msg_byte = pk_byte(pk, 10);
                33: msg_byte = pk_byte(pk, 11);
                34: msg_byte = pk_byte(pk, 12);
                35: msg_byte = pk_byte(pk, 13);
                36: msg_byte = pk_byte(pk, 14);
                37: msg_byte = pk_byte(pk, 15);
                38: msg_byte = pk_byte(pk, 16);
                39: msg_byte = pk_byte(pk, 17);
                40: msg_byte = pk_byte(pk, 18);
                41: msg_byte = pk_byte(pk, 19);
                42: msg_byte = pk_byte(pk, 20);
                43: msg_byte = pk_byte(pk, 21);
                44: msg_byte = pk_byte(pk, 22);
                45: msg_byte = pk_byte(pk, 23);
                46: msg_byte = pk_byte(pk, 24);
                47: msg_byte = pk_byte(pk, 25);
                48: msg_byte = pk_byte(pk, 26);
                49: msg_byte = pk_byte(pk, 27);
                50: msg_byte = pk_byte(pk, 28);
                51: msg_byte = pk_byte(pk, 29);
                52: msg_byte = pk_byte(pk, 30);
                53: msg_byte = pk_byte(pk, 31);
                54: msg_byte = 8'h80;
                62: msg_byte = 8'h01;
                63: msg_byte = 8'hb0;
                default: msg_byte = 8'h00;
            endcase
        end
    endfunction

    function automatic [511:0] make_block;
        input [31:0] ts;
        input [255:0] pk;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                make_block[511 - i * 8 -: 8] = msg_byte(i, ts, pk);
        end
    endfunction

    logic [31:0] current_w;
    logic [31:0] f;
    logic [31:0] k;
    logic [31:0] temp;
    logic [31:0] next_a, next_b, next_c, next_d, next_e;

    always_comb begin
        init_block = make_block(timestamp, public_key);
    end

    always_comb begin
        if (round < 16)
            current_w = w[round];
        else
            current_w = rol32(w[round - 3] ^ w[round - 8] ^ w[round - 14] ^ w[round - 16], 5'd1);

        if (round < 20) begin
            f = (b & c) | ((~b) & d);
            k = 32'h5a827999;
        end else if (round < 40) begin
            f = b ^ c ^ d;
            k = 32'h6ed9eba1;
        end else if (round < 60) begin
            f = (b & c) | (b & d) | (c & d);
            k = 32'h8f1bbcdc;
        end else begin
            f = b ^ c ^ d;
            k = 32'hca62c1d6;
        end

        temp = rol32(a, 5'd5) + f + e + k + current_w;
        next_a = temp;
        next_b = a;
        next_c = rol32(b, 5'd30);
        next_d = c;
        next_e = d;
    end

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            round <= 7'd0;
            a <= 32'd0;
            b <= 32'd0;
            c <= 32'd0;
            d <= 32'd0;
            e <= 32'd0;
            fingerprint <= 160'd0;
            done <= 1'b0;
            for (i = 0; i < 80; i = i + 1)
                w[i] <= 32'd0;
        end else begin
            done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1)
                            w[i] <= init_block[511 - i * 32 -: 32];
                        a <= H0_INIT;
                        b <= H1_INIT;
                        c <= H2_INIT;
                        d <= H3_INIT;
                        e <= H4_INIT;
                        round <= 7'd0;
                        state <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    if (round >= 16)
                        w[round] <= current_w;
                    a <= next_a;
                    b <= next_b;
                    c <= next_c;
                    d <= next_d;
                    e <= next_e;

                    if (round == 7'd79) begin
                        fingerprint <= {H0_INIT + next_a, H1_INIT + next_b, H2_INIT + next_c,
                                        H3_INIT + next_d, H4_INIT + next_e};
                        state <= ST_DONE;
                    end else begin
                        round <= round + 1'b1;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
