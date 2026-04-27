`timescale 1ns / 1ps

module tb_ed25519_fixedbase_table_select_pipe;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [4:0] pos = 5'd0;
    logic signed [7:0] digit = 8'sd0;
    logic signed [319:0] yplusx;
    logic signed [319:0] yminusx;
    logic signed [319:0] xy2d;
    logic done;

    logic signed [319:0] ref_yplusx_abs;
    logic signed [319:0] ref_yminusx_abs;
    logic signed [319:0] ref_xy2d_abs;
    logic ref_negative;

    ed25519_fixedbase_table_select_pipe dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .pos(pos),
        .digit(digit),
        .yplusx(yplusx),
        .yminusx(yminusx),
        .xy2d(xy2d),
        .done(done)
    );

    select ref_select (
        .pos(pos),
        .b(digit),
        .t_yplusx(ref_yplusx_abs),
        .t_yminusx(ref_yminusx_abs),
        .t_xy2d(ref_xy2d_abs),
        .bnegative(ref_negative)
    );

    always #5 clk = ~clk;

    function automatic logic signed [319:0] fe_neg_limbwise(input logic signed [319:0] value);
        logic signed [319:0] result;
        begin
            for (int i = 0; i < 10; i++) begin
                result[32*i +: 32] = -value[32*i +: 32];
            end
            return result;
        end
    endfunction

    task automatic run_case(input logic [4:0] pos_value, input logic signed [7:0] digit_value);
        logic signed [319:0] expected_yplusx;
        logic signed [319:0] expected_yminusx;
        logic signed [319:0] expected_xy2d;
        begin
            pos = pos_value;
            digit = digit_value;
            #1;

            if (ref_negative) begin
                expected_yplusx = ref_yminusx_abs;
                expected_yminusx = ref_yplusx_abs;
                expected_xy2d = fe_neg_limbwise(ref_xy2d_abs);
            end else begin
                expected_yplusx = ref_yplusx_abs;
                expected_yminusx = ref_yminusx_abs;
                expected_xy2d = ref_xy2d_abs;
            end

            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            @(negedge clk);
            start = 1'b0;
            @(posedge clk);
            #1;

            if (!done) begin
                $fatal(1, "done did not assert pos=%0d digit=%0d", pos_value, digit_value);
            end
            if (yplusx !== expected_yplusx || yminusx !== expected_yminusx || xy2d !== expected_xy2d) begin
                $fatal(1, "mismatch pos=%0d digit=%0d", pos_value, digit_value);
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        for (int p = 0; p < 32; p++) begin
            for (int d = -8; d <= 8; d++) begin
                run_case(p[4:0], d[7:0]);
            end
        end

        $display("PASS tb_ed25519_fixedbase_table_select_pipe");
        $finish;
    end
endmodule
