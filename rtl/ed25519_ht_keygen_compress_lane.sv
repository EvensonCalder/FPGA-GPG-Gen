`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_keygen_compress_lane (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         in_valid,
    output logic         in_ready,
    input  logic [255:0] in_seed,
    input  fe17_t        in_x,
    input  fe17_t        in_y,
    input  fe17_t        in_z,

    output logic         out_valid,
    input  logic         out_ready,
    output logic [255:0] out_seed,
    output logic [255:0] out_public_key
);
    typedef enum logic [1:0] {
        C_IDLE,
        C_START,
        C_BUSY
    } state_t;

    state_t state;
    logic [255:0] seed_q;
    fe17_t x_q, y_q, z_q;
    logic signed [319:0] x10, y10, z10;
    logic tobytes_done;
    logic [7:0] public_bytes [31:0];

    assign in_ready = state == C_IDLE && (!out_valid || out_ready);

    ge_p3_tobytes u_tobytes (
        .clk(clk), .rst(rst_n), .start(state == C_START),
        .X(x10), .Y(y10), .Z(z10), .s(public_bytes), .done(tobytes_done)
    );

    ed25519_ht_fe17_to_fe10 cX(.fe17(x_q), .fe10(x10));
    ed25519_ht_fe17_to_fe10 cY(.fe17(y_q), .fe10(y10));
    ed25519_ht_fe17_to_fe10 cZ(.fe17(z_q), .fe10(z10));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= C_IDLE;
            seed_q <= 256'd0;
            x_q <= '0;
            y_q <= '0;
            z_q <= '0;
            out_valid <= 1'b0;
            out_seed <= 256'd0;
            out_public_key <= 256'd0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;

            unique case (state)
                C_IDLE: begin
                    if (in_valid && in_ready) begin
                        seed_q <= in_seed;
                        x_q <= in_x;
                        y_q <= in_y;
                        z_q <= in_z;
                        state <= C_START;
                    end
                end
                C_START: state <= C_BUSY;
                C_BUSY: begin
                    if (tobytes_done) begin
                        out_seed <= seed_q;
                        out_public_key <= {public_bytes[31], public_bytes[30], public_bytes[29], public_bytes[28],
                                           public_bytes[27], public_bytes[26], public_bytes[25], public_bytes[24],
                                           public_bytes[23], public_bytes[22], public_bytes[21], public_bytes[20],
                                           public_bytes[19], public_bytes[18], public_bytes[17], public_bytes[16],
                                           public_bytes[15], public_bytes[14], public_bytes[13], public_bytes[12],
                                           public_bytes[11], public_bytes[10], public_bytes[9],  public_bytes[8],
                                           public_bytes[7],  public_bytes[6],  public_bytes[5],  public_bytes[4],
                                           public_bytes[3],  public_bytes[2],  public_bytes[1],  public_bytes[0]};
                        out_valid <= 1'b1;
                        state <= C_IDLE;
                    end
                end
                default: state <= C_IDLE;
            endcase
        end
    end
endmodule
