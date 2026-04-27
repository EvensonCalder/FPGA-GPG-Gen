`timescale 1ns / 1ps

module tb_ed25519_ge_madd_v1;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;

    logic signed [319:0] p_X = 320'sd0;
    logic signed [319:0] p_Y = 320'sd0;
    logic signed [319:0] p_Z = 320'sd0;
    logic signed [319:0] p_T = 320'sd0;
    logic signed [319:0] q_yplusx = 320'sd0;
    logic signed [319:0] q_yminusx = 320'sd0;
    logic signed [319:0] q_xy2d = 320'sd0;

    logic signed [319:0] dut_X;
    logic signed [319:0] dut_Y;
    logic signed [319:0] dut_Z;
    logic signed [319:0] dut_T;
    logic dut_done;

    logic signed [319:0] ref_X;
    logic signed [319:0] ref_Y;
    logic signed [319:0] ref_Z;
    logic signed [319:0] ref_T;
    logic ref_done;

    always #5 clk = ~clk;

    ed25519_ge_madd_v1 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .p_X(p_X),
        .p_Y(p_Y),
        .p_Z(p_Z),
        .p_T(p_T),
        .q_yplusx(q_yplusx),
        .q_yminusx(q_yminusx),
        .q_xy2d(q_xy2d),
        .r_X(dut_X),
        .r_Y(dut_Y),
        .r_Z(dut_Z),
        .r_T(dut_T),
        .done(dut_done)
    );

    ge_top u_ref (
        .clk(clk),
        .start(start),
        .rst_n(rst_n),
        .opcode_in(3'd1),
        .p_X(p_X),
        .p_Y(p_Y),
        .p_Z(p_Z),
        .p_T(p_T),
        .q_1(q_yplusx),
        .q_2(q_yminusx),
        .q_3(q_xy2d),
        .q_4(320'sd0),
        .r_x(ref_X),
        .r_y(ref_Y),
        .r_z(ref_Z),
        .r_t(ref_T),
        .done_TOP(ref_done)
    );

    function automatic logic signed [319:0] random_fe(input int seed_offset);
        logic signed [319:0] result;
        logic signed [31:0] limb;
        begin
            result = 320'sd0;
            for (int i = 0; i < 10; i++) begin
                limb = $signed($urandom_range(0, 2000000)) - 32'sd1000000 + seed_offset;
                result[32*i +: 32] = limb;
            end
            return result;
        end
    endfunction

    task automatic run_case(
        input logic signed [319:0] case_p_X,
        input logic signed [319:0] case_p_Y,
        input logic signed [319:0] case_p_Z,
        input logic signed [319:0] case_p_T,
        input logic signed [319:0] case_q_yplusx,
        input logic signed [319:0] case_q_yminusx,
        input logic signed [319:0] case_q_xy2d
    );
        logic dut_seen;
        logic ref_seen;
        logic signed [319:0] got_X;
        logic signed [319:0] got_Y;
        logic signed [319:0] got_Z;
        logic signed [319:0] got_T;
        logic signed [319:0] exp_X;
        logic signed [319:0] exp_Y;
        logic signed [319:0] exp_Z;
        logic signed [319:0] exp_T;
        int timeout;
        begin
            @(posedge clk);
            p_X = case_p_X;
            p_Y = case_p_Y;
            p_Z = case_p_Z;
            p_T = case_p_T;
            q_yplusx = case_q_yplusx;
            q_yminusx = case_q_yminusx;
            q_xy2d = case_q_xy2d;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            dut_seen = 1'b0;
            ref_seen = 1'b0;
            timeout = 0;
            while (!(dut_seen && ref_seen) && timeout < 1000) begin
                @(posedge clk);
                timeout++;
                if (dut_done && !dut_seen) begin
                    got_X = dut_X;
                    got_Y = dut_Y;
                    got_Z = dut_Z;
                    got_T = dut_T;
                    dut_seen = 1'b1;
                end
                if (ref_done && !ref_seen) begin
                    exp_X = ref_X;
                    exp_Y = ref_Y;
                    exp_Z = ref_Z;
                    exp_T = ref_T;
                    ref_seen = 1'b1;
                end
            end

            if (!dut_seen || !ref_seen) begin
                $fatal(1, "timeout dut_seen=%0d ref_seen=%0d", dut_seen, ref_seen);
            end
            if (got_X !== exp_X || got_Y !== exp_Y || got_Z !== exp_Z || got_T !== exp_T) begin
                $fatal(1, "mismatch\ngot X=%080x\nexp X=%080x\ngot Y=%080x\nexp Y=%080x\ngot Z=%080x\nexp Z=%080x\ngot T=%080x\nexp T=%080x",
                       got_X, exp_X, got_Y, exp_Y, got_Z, exp_Z, got_T, exp_T);
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        run_case(
            320'sd0,
            320'sd1,
            320'sd1,
            320'sd0,
            320'h0000000a000000090000000800000007000000060000000500000004000000030000000200000001,
            320'h00000014000000130000001200000011000000100000000f0000000e0000000d0000000c0000000b,
            320'h0000001e0000001d0000001c0000001b0000001a0000001900000018000000170000001600000015
        );

        for (int i = 0; i < 20; i++) begin
            run_case(
                random_fe(i),
                random_fe(i + 1),
                random_fe(i + 2),
                random_fe(i + 3),
                random_fe(i + 4),
                random_fe(i + 5),
                random_fe(i + 6)
            );
        end

        $display("PASS tb_ed25519_ge_madd_v1");
        $finish;
    end
endmodule
