`timescale 1ns / 1ps

module ed25519_fixedbase_select_shared (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [2:0]       req,
    input  logic [4:0]       pos0,
    input  logic [4:0]       pos1,
    input  logic [4:0]       pos2,
    input  logic signed [7:0] digit0,
    input  logic signed [7:0] digit1,
    input  logic signed [7:0] digit2,
    output logic [2:0]       grant,
    output logic signed [319:0] yplusx,
    output logic signed [319:0] yminusx,
    output logic signed [319:0] xy2d,
    output logic [2:0]       done
);
    logic [1:0] owner;
    logic [1:0] next_owner;
    logic       sel_start;
    logic [4:0] sel_pos;
    logic signed [7:0] sel_digit;
    logic signed [319:0] sel_yplusx;
    logic signed [319:0] sel_yminusx;
    logic signed [319:0] sel_xy2d;
    logic sel_done;

    logic [1:0] sel_owner;
    logic sel_busy;

    logic [2:0] req_masked;
    assign req_masked = req & ~done;

    always_comb begin
        sel_start = 1'b0;
        sel_pos = 5'd0;
        sel_digit = 8'sd0;
        grant = 3'd0;

        if (!sel_busy) begin
            unique case (owner)
                2'd0: if (req_masked[0]) begin grant[0]=1'b1; sel_start=1'b1; sel_pos=pos0; sel_digit=digit0; end
                2'd1: if (req_masked[1]) begin grant[1]=1'b1; sel_start=1'b1; sel_pos=pos1; sel_digit=digit1; end
                2'd2: if (req_masked[2]) begin grant[2]=1'b1; sel_start=1'b1; sel_pos=pos2; sel_digit=digit2; end
            endcase
        end
    end

    always_comb begin
        next_owner = owner;
        if (sel_start) next_owner = (owner == 2'd2) ? 2'd0 : (owner + 2'd1);
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            owner <= 2'd0;
            sel_owner <= 2'd0;
            sel_busy <= 1'b0;
            yplusx <= 320'sd0;
            yminusx <= 320'sd0;
            xy2d <= 320'sd0;
            done <= 3'd0;
        end else begin
            done <= 3'd0;
            owner <= next_owner;

            if (sel_start) begin
                sel_owner <= owner;
                sel_busy <= 1'b1;
            end

            if (sel_done) begin
                sel_busy <= 1'b0;
                yplusx <= sel_yplusx;
                yminusx <= sel_yminusx;
                xy2d <= sel_xy2d;
                done[sel_owner] <= 1'b1;
            end
        end
    end

    ed25519_fixedbase_table_select_pipe u_sel (
        .clk(clk),
        .rst_n(rst_n),
        .start(sel_start),
        .pos(sel_pos),
        .digit(sel_digit),
        .yplusx(sel_yplusx),
        .yminusx(sel_yminusx),
        .xy2d(sel_xy2d),
        .done(sel_done)
    );
endmodule
