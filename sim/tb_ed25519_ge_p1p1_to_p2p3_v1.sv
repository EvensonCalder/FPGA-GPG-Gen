`timescale 1ns / 1ps

module tb_ed25519_ge_p1p1_to_p2p3_v1;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic to_p3 = 1'b0;

    logic signed [319:0] p_X = 320'sd0;
    logic signed [319:0] p_Y = 320'sd0;
    logic signed [319:0] p_Z = 320'sd0;
    logic signed [319:0] p_T = 320'sd0;

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
    logic signed [319:0] ref_p2_X;
    logic signed [319:0] ref_p2_Y;
    logic signed [319:0] ref_p2_Z;
    logic signed [319:0] ref_p2_T;
    logic ref_p2_done;
    logic signed [319:0] ref_p3_X;
    logic signed [319:0] ref_p3_Y;
    logic signed [319:0] ref_p3_Z;
    logic signed [319:0] ref_p3_T;
    logic ref_p3_done;

    always #5 clk = ~clk;

    ed25519_ge_p1p1_to_p2p3_v1 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .to_p3(to_p3),
        .p_X(p_X),
        .p_Y(p_Y),
        .p_Z(p_Z),
        .p_T(p_T),
        .r_X(dut_X),
        .r_Y(dut_Y),
        .r_Z(dut_Z),
        .r_T(dut_T),
        .done(dut_done)
    );

    ge_top u_ref_p2 (
        .clk(clk),
        .start(start && !to_p3),
        .rst_n(rst_n),
        .opcode_in(3'd3),
        .p_X(p_X),
        .p_Y(p_Y),
        .p_Z(p_Z),
        .p_T(p_T),
        .q_1(320'sd0),
        .q_2(320'sd0),
        .q_3(320'sd0),
        .q_4(320'sd0),
        .r_x(ref_p2_X),
        .r_y(ref_p2_Y),
        .r_z(ref_p2_Z),
        .r_t(ref_p2_T),
        .done_TOP(ref_p2_done)
    );

    ge_top u_ref_p3 (
        .clk(clk),
        .start(start && to_p3),
        .rst_n(rst_n),
        .opcode_in(3'd4),
        .p_X(p_X),
        .p_Y(p_Y),
        .p_Z(p_Z),
        .p_T(p_T),
        .q_1(320'sd0),
        .q_2(320'sd0),
        .q_3(320'sd0),
        .q_4(320'sd0),
        .r_x(ref_p3_X),
        .r_y(ref_p3_Y),
        .r_z(ref_p3_Z),
        .r_t(ref_p3_T),
        .done_TOP(ref_p3_done)
    );

    assign ref_X = to_p3 ? ref_p3_X : ref_p2_X;
    assign ref_Y = to_p3 ? ref_p3_Y : ref_p2_Y;
    assign ref_Z = to_p3 ? ref_p3_Z : ref_p2_Z;
    assign ref_T = to_p3 ? ref_p3_T : ref_p2_T;
    assign ref_done = to_p3 ? ref_p3_done : ref_p2_done;

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
        input logic case_to_p3,
        input logic signed [319:0] case_p_X,
        input logic signed [319:0] case_p_Y,
        input logic signed [319:0] case_p_Z,
        input logic signed [319:0] case_p_T
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
            while (dut_done || ref_p2_done || ref_p3_done) begin
                @(posedge clk);
            end
            to_p3 = case_to_p3;
            p_X = case_p_X;
            p_Y = case_p_Y;
            p_Z = case_p_Z;
            p_T = case_p_T;
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
                $fatal(1, "timeout to_p3=%0d dut_seen=%0d ref_seen=%0d", case_to_p3, dut_seen, ref_seen);
            end
            if (got_X !== exp_X || got_Y !== exp_Y || got_Z !== exp_Z || (case_to_p3 && got_T !== exp_T)) begin
                $fatal(1, "mismatch to_p3=%0d\ngot X=%080x\nexp X=%080x\ngot Y=%080x\nexp Y=%080x\ngot Z=%080x\nexp Z=%080x\ngot T=%080x\nexp T=%080x",
                       case_to_p3, got_X, exp_X, got_Y, exp_Y, got_Z, exp_Z, got_T, exp_T);
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        run_case(
            1'b0,
            320'h0000000a000000090000000800000007000000060000000500000004000000030000000200000001,
            320'h00000014000000130000001200000011000000100000000f0000000e0000000d0000000c0000000b,
            320'h0000001e0000001d0000001c0000001b0000001a0000001900000018000000170000001600000015,
            320'h0000002800000027000000260000002500000024000000230000002200000021000000200000001f
        );

        run_case(
            1'b1,
            320'h0000000a000000090000000800000007000000060000000500000004000000030000000200000001,
            320'h00000014000000130000001200000011000000100000000f0000000e0000000d0000000c0000000b,
            320'h0000001e0000001d0000001c0000001b0000001a0000001900000018000000170000001600000015,
            320'h0000002800000027000000260000002500000024000000230000002200000021000000200000001f
        );

        for (int i = 0; i < 20; i++) begin
            run_case(1'b0, random_fe(i), random_fe(i + 1), random_fe(i + 2), random_fe(i + 3));
            run_case(1'b1, random_fe(i + 4), random_fe(i + 5), random_fe(i + 6), random_fe(i + 7));
        end

        $display("PASS tb_ed25519_ge_p1p1_to_p2p3_v1");
        $finish;
    end
endmodule
