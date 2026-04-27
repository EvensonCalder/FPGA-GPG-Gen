`timescale 1ns / 1ps

module tb_ed25519_fixedbase_context_v2_shared;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [255:0] scalar = 256'd0;

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

    ed25519_fixedbase_context_v2_shared dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .scalar(scalar),
        .r_X(dut_X),
        .r_Y(dut_Y),
        .r_Z(dut_Z),
        .r_T(dut_T),
        .done(dut_done)
    );

    base_TOP u_ref (
        .clk(clk),
        .reset(rst_n),
        .start(start),
        .op_operand(1'b1),
        .a(scalar),
        .b(256'd0),
        .A_X(320'sd0),
        .A_Y(320'sd0),
        .A_Z(320'sd0),
        .A_T(320'sd0),
        .r_X(ref_X),
        .r_Y(ref_Y),
        .r_Z(ref_Z),
        .r_T(ref_T),
        .done(ref_done)
    );

    task automatic run_case(input logic [255:0] scalar_value);
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
        int dut_cycles;
        int ref_cycles;
        begin
            @(posedge clk);
            while (dut_done || ref_done) @(posedge clk);
            scalar = scalar_value;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            dut_seen = 1'b0;
            ref_seen = 1'b0;
            timeout = 0;
            dut_cycles = 0;
            ref_cycles = 0;
            while (!(dut_seen && ref_seen) && timeout < 100000) begin
                @(posedge clk);
                timeout++;
                if (!dut_seen) dut_cycles++;
                if (!ref_seen) ref_cycles++;
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
                $display("timeout state=%0d idx=%0d dbl_count=%0d engine_state=%0d engine_done=%0d",
                         dut.state, dut.idx, dut.dbl_count, dut.u_engine.state, dut.engine_done);
                $fatal(1, "timeout dut_seen=%0d ref_seen=%0d", dut_seen, ref_seen);
            end
            if (got_X !== exp_X || got_Y !== exp_Y || got_Z !== exp_Z || got_T !== exp_T) begin
                $fatal(1, "mismatch scalar=%064x\ngot X=%080x\nexp X=%080x\ngot Y=%080x\nexp Y=%080x\ngot Z=%080x\nexp Z=%080x\ngot T=%080x\nexp T=%080x",
                       scalar_value, got_X, exp_X, got_Y, exp_Y, got_Z, exp_Z, got_T, exp_T);
            end
            $display("case scalar=%064x dut_cycles=%0d ref_cycles=%0d", scalar_value, dut_cycles, ref_cycles);
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        run_case(256'h5f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020140);
        run_case(256'h607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db16158);
        $display("PASS tb_ed25519_fixedbase_context_v2_shared");
        $finish;
    end
endmodule
