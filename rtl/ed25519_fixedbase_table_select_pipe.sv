`timescale 1ns / 1ps

module ed25519_fixedbase_table_select_pipe (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             start,
    input  logic [4:0]       pos,
    input  logic signed [7:0] digit,
    output logic signed [319:0] yplusx,
    output logic signed [319:0] yminusx,
    output logic signed [319:0] xy2d,
    output logic             done
);
    logic [4:0] pos_q;
    logic signed [7:0] digit_q;
    logic valid_q;

    logic negative_q;
    logic [7:0] abs_digit_q;
    logic zero_q;
    logic [2:0] rom_j_q;

    logic signed [319:0] rom_yplusx;
    logic signed [319:0] rom_yminusx;
    logic signed [319:0] rom_xy2d;

    function automatic logic signed [319:0] fe_neg_limbwise(input logic signed [319:0] value);
        logic signed [319:0] result;
        begin
            for (int i = 0; i < 10; i++) begin
                result[32*i +: 32] = -value[32*i +: 32];
            end
            return result;
        end
    endfunction

    always_comb begin
        negative_q = digit_q < 0;
        abs_digit_q = negative_q ? -digit_q : digit_q;
        zero_q = abs_digit_q == 8'd0;
        rom_j_q = abs_digit_q[2:0] - 3'd1;
    end

    base_rom1 u_base_rom (
        .pos(pos_q),
        .j(rom_j_q),
        .t_yplusx(rom_yplusx),
        .t_yminusx(rom_yminusx),
        .t_xy2d(rom_xy2d)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pos_q <= 5'd0;
            digit_q <= 8'sd0;
            valid_q <= 1'b0;
            yplusx <= 320'sd0;
            yminusx <= 320'sd0;
            xy2d <= 320'sd0;
            done <= 1'b0;
        end else begin
            pos_q <= pos;
            digit_q <= digit;
            valid_q <= start;
            done <= valid_q;

            if (valid_q) begin
                if (zero_q) begin
                    yplusx <= {288'd0, 32'd1};
                    yminusx <= {288'd0, 32'd1};
                    xy2d <= 320'sd0;
                end else if (negative_q) begin
                    yplusx <= rom_yminusx;
                    yminusx <= rom_yplusx;
                    xy2d <= fe_neg_limbwise(rom_xy2d);
                end else begin
                    yplusx <= rom_yplusx;
                    yminusx <= rom_yminusx;
                    xy2d <= rom_xy2d;
                end
            end
        end
    end
endmodule
