`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_table #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer WINDOW_BITS = 9,
    parameter integer DIGITS = (256 + WINDOW_BITS - 1) / WINDOW_BITS
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [4:0] pos,
    input  logic signed [10:0] digit,
    output fe17_t      yplusx,
    output fe17_t      yminusx,
    output fe17_t      xy2d,
    output logic       done
);
    localparam int TABLE_BITS = WINDOW_BITS - 1;
    localparam int TABLE_ENTRIES = DIGITS * (1 << TABLE_BITS);
    (* rom_style = "block" *) logic [767:0] rom [0:TABLE_ENTRIES-1];
    logic valid_q;
    logic valid_corr_q;
    logic negative_q;
    logic negative_corr_q;
    logic zero_q;
    logic zero_corr_q;
    (* keep = "true" *) logic zero_q_yp;       // replicated: yplusx_raw control only
    (* keep = "true" *) logic zero_q_ym;       // replicated: yminusx_raw control only
    (* keep = "true" *) logic zero_q_xy;       // replicated: xy2d_raw control only
    logic [767:0] entry_q;
    fe17_t yplusx_raw_q;
    fe17_t yminusx_raw_q;
    logic [255:0] xy2d_raw_q;
    logic negative_in;
    logic [10:0] abs_digit_in;
    logic zero_in;
    logic [TABLE_BITS-1:0] j_idx_in;
    logic [10:0] j_idx_wide_in;

    initial begin
        $readmemh(INIT_FILE, rom);
    end

    always_comb begin
        negative_in = digit < 0;
        abs_digit_in = negative_in ? -digit : digit;
        zero_in = abs_digit_in == 11'd0;
        j_idx_wide_in = abs_digit_in - 11'd1;
        j_idx_in = j_idx_wide_in[TABLE_BITS-1:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            valid_corr_q <= 1'b0;
            negative_q <= 1'b0;
            negative_corr_q <= 1'b0;
            zero_q <= 1'b0;
            zero_corr_q <= 1'b0;
            zero_q_yp <= 1'b0;
            zero_q_ym <= 1'b0;
            zero_q_xy <= 1'b0;
            entry_q <= '0;
            yplusx_raw_q <= '0;
            yminusx_raw_q <= '0;
            xy2d_raw_q <= 256'd0;
            yplusx <= '0;
            yminusx <= '0;
            xy2d <= '0;
            done <= 1'b0;
        end else begin
            if (start) begin
                entry_q <= rom[(pos * (1 << TABLE_BITS)) + j_idx_in];
                negative_q <= negative_in;
                zero_q <= zero_in;
                zero_q_yp <= zero_in;
                zero_q_ym <= zero_in;
                zero_q_xy <= zero_in;
            end
            valid_q <= start;
            valid_corr_q <= valid_q;
            done <= valid_corr_q;

            if (valid_q) begin
                if (zero_q_yp) begin
                    yplusx_raw_q <= fe17_t'(255'd1);
                end else if (negative_q) begin
                    yplusx_raw_q <= fe17_t'(entry_q[511:256]);
                end else begin
                    yplusx_raw_q <= fe17_t'(entry_q[767:512]);
                end
                if (zero_q_ym) begin
                    yminusx_raw_q <= fe17_t'(255'd1);
                end else if (negative_q) begin
                    yminusx_raw_q <= fe17_t'(entry_q[767:512]);
                end else begin
                    yminusx_raw_q <= fe17_t'(entry_q[511:256]);
                end
                if (zero_q_xy)
                    xy2d_raw_q <= 256'd0;
                else
                    xy2d_raw_q <= entry_q[255:0];
                negative_corr_q <= negative_q;
                zero_corr_q <= zero_q;
            end

            if (valid_corr_q) begin
                yplusx <= yplusx_raw_q;
                yminusx <= yminusx_raw_q;
                if (zero_corr_q)
                    xy2d <= '0;
                else if (negative_corr_q)
                    xy2d <= (xy2d_raw_q == 256'd0) ? '0 : fe17_t'(255'((255'(1) << 255) - 255'd19) - xy2d_raw_q[254:0]);
                else
                    xy2d <= fe17_t'(xy2d_raw_q);
            end
        end
    end
endmodule
