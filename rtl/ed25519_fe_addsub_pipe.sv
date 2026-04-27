`timescale 1ns / 1ps

module ed25519_fe_addsub_pipe (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    input  logic              sub,
    input  logic signed [319:0] f,
    input  logic signed [319:0] g,
    output logic signed [319:0] h,
    output logic              done
);
    logic signed [319:0] f_q;
    logic signed [319:0] g_q;
    logic                sub_q;
    logic                valid_q;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            f_q <= 320'sd0;
            g_q <= 320'sd0;
            sub_q <= 1'b0;
            valid_q <= 1'b0;
            h <= 320'sd0;
            done <= 1'b0;
        end else begin
            f_q <= f;
            g_q <= g;
            sub_q <= sub;
            valid_q <= start;
            done <= valid_q;
            if (valid_q) begin
                for (int i = 0; i < 10; i++) begin
                    logic signed [32:0] limb_result;

                    if (sub_q) begin
                        limb_result = {f_q[32*i+31], f_q[32*i +: 32]} - {g_q[32*i+31], g_q[32*i +: 32]};
                    end else begin
                        limb_result = {f_q[32*i+31], f_q[32*i +: 32]} + {g_q[32*i+31], g_q[32*i +: 32]};
                    end
                    h[32*i +: 32] <= limb_result[31:0];
                end
            end
        end
    end
endmodule
