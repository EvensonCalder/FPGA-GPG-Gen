`timescale 1ns / 1ps

module ed25519_fixedbase_rom_bram (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             start,
    input  logic [4:0]       pos,
    input  logic [2:0]       j,
    output logic signed [319:0] t_yplusx,
    output logic signed [319:0] t_yminusx,
    output logic signed [319:0] t_xy2d,
    output logic             done
);
    localparam string INIT_FILE = "build/fixedbase_rom.mem";

    logic [31:0] rom [0:7679];

    initial begin
        $readmemh(INIT_FILE, rom);
    end

    logic [4:0] pos_q;
    logic [2:0] j_q;
    logic [1:0] phase;
    logic busy;

    function automatic logic [12:0] addr_fn(
        input logic [4:0] p, input logic [2:0] jj,
        input logic [1:0] ff, input logic [3:0] li
    );
        return 13'(p * 9'd240) + 13'(jj * 8'd30) + 13'(ff * 4'd10) + 13'(li);
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            phase <= 2'd0;
            done <= 1'b0;
            pos_q <= 5'd0;
            j_q <= 3'd0;
            t_yplusx <= 320'sd0;
            t_yminusx <= 320'sd0;
            t_xy2d <= 320'sd0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                pos_q <= pos;
                j_q <= j;
                busy <= 1'b1;
                phase <= 2'd0;
            end

            if (busy) begin
                case (phase)
                    2'd0: begin
                        for (int i = 0; i < 10; i++)
                            t_yplusx[32*i +: 32] <= $signed(rom[addr_fn(pos_q, j_q, 2'd0, i[3:0])]);
                        phase <= 2'd1;
                    end
                    2'd1: begin
                        for (int i = 0; i < 10; i++)
                            t_yminusx[32*i +: 32] <= $signed(rom[addr_fn(pos_q, j_q, 2'd1, i[3:0])]);
                        phase <= 2'd2;
                    end
                    2'd2: begin
                        for (int i = 0; i < 10; i++)
                            t_xy2d[32*i +: 32] <= $signed(rom[addr_fn(pos_q, j_q, 2'd2, i[3:0])]);
                        phase <= 2'd3;
                    end
                    2'd3: begin
                        done <= 1'b1;
                        busy <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule
