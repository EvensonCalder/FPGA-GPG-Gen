`timescale 1ns / 1ps

module trng_core #(
    parameter integer RO_COUNT        = 16,
    parameter integer STARTUP_SAMPLES = 65536,
    parameter integer RCT_CUTOFF      = 64,
    parameter integer APT_WINDOW      = 512,
    parameter integer APT_LOW         = 192,
    parameter integer APT_HIGH        = 320,
    parameter integer SAMPLE_DIV      = 8,
    parameter integer CONDITIONER_BITS = 32
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       random_ready,
    output reg  [7:0] random_byte,
    output reg        random_valid,
    output reg        health_fail,
    output reg        startup_done,
    output wire       raw_bit
);
    wire [RO_COUNT-1:0] ro_bits;

    xilinx_ro_bank #(
        .RO_COUNT(RO_COUNT)
    ) ro_bank_inst (
        .enable(1'b1),
        .ro_bits(ro_bits)
    );

    reg [RO_COUNT-1:0] ro_sample;
    reg [RO_COUNT-1:0] ro_sample_d;
    reg raw_mix;

    assign raw_bit = raw_mix;

    reg [31:0] startup_count;

    reg rct_last;
    reg [15:0] rct_count;

    reg [15:0] apt_count;
    reg [15:0] apt_ones;

    reg pair_phase;
    reg pair_first;
    reg [7:0] cond_count;
    reg [31:0] cond_word;
    reg [31:0] out_word;
    reg [1:0] out_count;
    reg out_active;
    reg [15:0] sample_div_count;

    wire can_pack = (!random_valid) || random_ready;

    function [31:0] mix32;
        input [31:0] x;
        reg [31:0] y;
        begin
            y = x ^ (x >> 16);
            y = y * 32'h7feb352d;
            y = y ^ (y >> 15);
            y = y * 32'h846ca68b;
            mix32 = y ^ (y >> 16);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ro_sample     <= {RO_COUNT{1'b0}};
            ro_sample_d   <= {RO_COUNT{1'b0}};
            raw_mix       <= 1'b0;
            startup_count <= 32'd0;
            startup_done  <= 1'b0;
            rct_last      <= 1'b0;
            rct_count     <= 16'd0;
            apt_count     <= 16'd0;
            apt_ones      <= 16'd0;
            pair_phase    <= 1'b0;
            pair_first    <= 1'b0;
            cond_count    <= 8'd0;
            cond_word     <= 32'd0;
            out_word      <= 32'd0;
            out_count     <= 2'd0;
            out_active    <= 1'b0;
            sample_div_count <= 16'd0;
            random_byte   <= 8'd0;
            random_valid  <= 1'b0;
            health_fail   <= 1'b0;
        end else begin
            ro_sample   <= ro_bits;
            ro_sample_d <= ro_sample;
            raw_mix     <= ^(ro_sample ^ {ro_sample_d[RO_COUNT-2:0], ro_sample_d[RO_COUNT-1]});

            if (sample_div_count == SAMPLE_DIV - 1)
                sample_div_count <= 16'd0;
            else
                sample_div_count <= sample_div_count + 1'b1;

            if (random_valid && random_ready)
                random_valid <= 1'b0;

            if (!startup_done) begin
                if (startup_count == STARTUP_SAMPLES - 1)
                    startup_done <= 1'b1;
                else
                    startup_count <= startup_count + 1'b1;
            end

            if (!startup_done) begin
                rct_last   <= raw_mix;
                rct_count  <= 16'd1;
                apt_count  <= 16'd0;
                apt_ones   <= 16'd0;
                pair_phase <= 1'b0;
                cond_count <= 8'd0;
                out_active <= 1'b0;
            end else if (sample_div_count == SAMPLE_DIV - 1) begin
                // Repetition Count Test on raw entropy samples.
                if (raw_mix == rct_last) begin
                    if (rct_count >= RCT_CUTOFF - 1)
                        health_fail <= 1'b1;
                    else
                        rct_count <= rct_count + 1'b1;
                end else begin
                    rct_last  <= raw_mix;
                    rct_count <= 16'd1;
                end

                // Adaptive Proportion Test on raw entropy samples.
                if (apt_count == APT_WINDOW - 1) begin
                    if ((apt_ones + raw_mix < APT_LOW) || (apt_ones + raw_mix > APT_HIGH))
                        health_fail <= 1'b1;
                    apt_count <= 16'd0;
                    apt_ones  <= 16'd0;
                end else begin
                    apt_count <= apt_count + 1'b1;
                    apt_ones  <= apt_ones + raw_mix;
                end
                if (out_active && can_pack) begin
                    random_byte  <= out_word[7:0];
                    random_valid <= 1'b1;
                    out_word     <= {8'd0, out_word[31:8]};

                    if (out_count == 2'd3) begin
                        out_count  <= 2'd0;
                        out_active <= 1'b0;
                    end else begin
                        out_count <= out_count + 1'b1;
                    end
                end

                if (!health_fail && !out_active) begin
                    if (!pair_phase) begin
                        pair_first <= raw_mix;
                        pair_phase <= 1'b1;
                    end else begin
                        pair_phase <= 1'b0;

                        if (pair_first != raw_mix) begin
                            cond_word <= {pair_first, cond_word[31:1]};

                            if (cond_count == CONDITIONER_BITS - 1) begin
                                out_word   <= mix32({pair_first, cond_word[31:1]});
                                out_count  <= 2'd0;
                                out_active <= 1'b1;
                                cond_count <= 8'd0;
                            end else begin
                                cond_count <= cond_count + 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
