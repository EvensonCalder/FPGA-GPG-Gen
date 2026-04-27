`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_table #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [4:0] pos,
    input  logic signed [7:0] digit,
    output fe17_t      yplusx,
    output fe17_t      yminusx,
    output fe17_t      xy2d,
    output logic       done
);
    logic [767:0] rom [0:255];
    logic [4:0] pos_q;
    logic signed [7:0] digit_q;
    logic valid_q;
    logic negative;
    logic [7:0] abs_digit;
    logic zero;
    logic [2:0] j_idx;
    logic [767:0] entry;

    initial begin
        $readmemh(INIT_FILE, rom);
    end

    always_comb begin
        negative = digit_q < 0;
        abs_digit = negative ? -digit_q : digit_q;
        zero = abs_digit == 8'd0;
        j_idx = abs_digit[2:0] - 3'd1;
        entry = rom[{pos_q, j_idx}];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_q <= 5'd0;
            digit_q <= 8'sd0;
            valid_q <= 1'b0;
            yplusx <= '0;
            yminusx <= '0;
            xy2d <= '0;
            done <= 1'b0;
        end else begin
            pos_q <= pos;
            digit_q <= digit;
            valid_q <= start;
            done <= valid_q;

            if (valid_q) begin
                if (zero) begin
                    yplusx <= fe17_t'(255'd1);
                    yminusx <= fe17_t'(255'd1);
                    xy2d <= '0;
                end else if (negative) begin
                    yplusx <= fe17_t'(entry[511:256]);
                    yminusx <= fe17_t'(entry[767:512]);
                    xy2d <= (entry[255:0] == 256'd0) ? '0 : fe17_t'(255'((255'(1) << 255) - 255'd19) - entry[254:0]);
                end else begin
                    yplusx <= fe17_t'(entry[767:512]);
                    yminusx <= fe17_t'(entry[511:256]);
                    xy2d <= fe17_t'(entry[255:0]);
                end
            end
        end
    end
endmodule
