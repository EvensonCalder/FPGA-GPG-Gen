`timescale 1ns / 1ps

module tb_ed25519_fe_addsub_pipe;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic sub = 1'b0;
    logic signed [319:0] f = 320'sd0;
    logic signed [319:0] g = 320'sd0;
    logic signed [319:0] h;
    logic done;

    ed25519_fe_addsub_pipe dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .sub(sub),
        .f(f),
        .g(g),
        .h(h),
        .done(done)
    );

    always #5 clk = ~clk;

    function automatic logic signed [319:0] expected_result(
        input logic is_sub,
        input logic signed [319:0] a,
        input logic signed [319:0] b
    );
        logic signed [319:0] result;
        logic signed [32:0] limb_result;
        begin
            result = 320'sd0;
            for (int i = 0; i < 10; i++) begin
                if (is_sub) begin
                    limb_result = {a[32*i+31], a[32*i +: 32]} - {b[32*i+31], b[32*i +: 32]};
                end else begin
                    limb_result = {a[32*i+31], a[32*i +: 32]} + {b[32*i+31], b[32*i +: 32]};
                end
                result[32*i +: 32] = limb_result[31:0];
            end
            return result;
        end
    endfunction

    task automatic run_case(
        input logic is_sub,
        input logic signed [319:0] a,
        input logic signed [319:0] b
    );
        logic signed [319:0] expected;
        begin
            expected = expected_result(is_sub, a, b);
            @(posedge clk);
            f = a;
            g = b;
            sub = is_sub;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            @(posedge clk);

            if (!done) begin
                $fatal(1, "done did not assert two cycles after start");
            end
            if (h !== expected) begin
                $fatal(1, "mismatch sub=%0d got=%080x expected=%080x", is_sub, h, expected);
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        run_case(1'b0, 320'sd0, 320'sd0);
        run_case(1'b0, 320'h0000000a000000090000000800000007000000060000000500000004000000030000000200000001, 320'h1);
        run_case(1'b1, 320'h0000000a000000090000000800000007000000060000000500000004000000030000000200000001, 320'h1);

        for (int i = 0; i < 100; i++) begin
            logic signed [319:0] a;
            logic signed [319:0] b;

            a = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(),
                 $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
            b = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(),
                 $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
            run_case(1'b0, a, b);
            run_case(1'b1, a, b);
        end

        $display("PASS tb_ed25519_fe_addsub_pipe");
        $finish;
    end
endmodule
