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
    (* rom_style = "block" *) logic [767:0] rom [0:255];
    logic valid_q;
    logic negative_q;
    logic zero_q;
    logic [767:0] entry_q;
    logic negative_in;
    logic [7:0] abs_digit_in;
    logic zero_in;
    logic [2:0] j_idx_in;

    initial begin
        $readmemh(INIT_FILE, rom);
    end

    always_comb begin
        negative_in = digit < 0;
        abs_digit_in = negative_in ? -digit : digit;
        zero_in = abs_digit_in == 8'd0;
        j_idx_in = abs_digit_in[2:0] - 3'd1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            negative_q <= 1'b0;
            zero_q <= 1'b0;
            entry_q <= '0;
            yplusx <= '0;
            yminusx <= '0;
            xy2d <= '0;
            done <= 1'b0;
        end else begin
            if (start) begin
                entry_q <= rom[{pos, j_idx_in}];
                negative_q <= negative_in;
                zero_q <= zero_in;
            end
            valid_q <= start;
            done <= valid_q;

            if (valid_q) begin
                if (zero_q) begin
                    yplusx <= fe17_t'(255'd1);
                    yminusx <= fe17_t'(255'd1);
                    xy2d <= '0;
                end else if (negative_q) begin
                    yplusx <= fe17_t'(entry_q[511:256]);
                    yminusx <= fe17_t'(entry_q[767:512]);
                    xy2d <= (entry_q[255:0] == 256'd0) ? '0 : fe17_t'(255'((255'(1) << 255) - 255'd19) - entry_q[254:0]);
                end else begin
                    yplusx <= fe17_t'(entry_q[767:512]);
                    yminusx <= fe17_t'(entry_q[511:256]);
                    xy2d <= fe17_t'(entry_q[255:0]);
                end
            end
        end
    end
endmodule
