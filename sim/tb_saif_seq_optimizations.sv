`timescale 1ns / 1ps

module tb_saif_seq_optimizations;
    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic signed [511:0] carry_in;
    logic signed [511:0] carry_ref_out;
    logic signed [511:0] carry_seq_out;
    logic carry_start;
    logic carry_done;
    logic carry_busy;

    logic signed [319:0] bytes_in;
    wire [7:0] bytes_ref_out [31:0];
    wire [7:0] bytes_seq_out [31:0];
    logic bytes_start;
    logic bytes_done;
    logic bytes_busy;

    integer case_idx;
    integer byte_idx;
    integer limb_idx;
    logic [31:0] lfsr;

    always #5 clk = ~clk;

    carry_prop u_carry_ref (
        .e_in(carry_in),
        .e_out(carry_ref_out)
    );

    carry_prop_seq u_carry_seq (
        .clk(clk),
        .reset(rst_n),
        .start(carry_start),
        .e_in(carry_in),
        .e_out(carry_seq_out),
        .busy(carry_busy),
        .done(carry_done)
    );

    fe_tobytes u_bytes_ref (
        .h(bytes_in),
        .s(bytes_ref_out)
    );

    fe_tobytes_seq u_bytes_seq (
        .clk(clk),
        .reset(rst_n),
        .start(bytes_start),
        .h(bytes_in),
        .s(bytes_seq_out),
        .busy(bytes_busy),
        .done(bytes_done)
    );

    function automatic [31:0] next_lfsr;
        input [31:0] x;
        begin
            next_lfsr = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
        end
    endfunction

    task automatic run_carry_case;
        begin
            carry_start = 1'b1;
            @(posedge clk);
            #1;
            carry_start = 1'b0;
            wait (carry_done);
            #1;
            if (carry_seq_out !== carry_ref_out) begin
                $display("FAIL carry case=%0d seq=%0128h ref=%0128h", case_idx, carry_seq_out, carry_ref_out);
                $fatal(1);
            end
            @(posedge clk);
        end
    endtask

    task automatic run_bytes_case;
        begin
            bytes_start = 1'b1;
            @(posedge clk);
            #1;
            bytes_start = 1'b0;
            wait (bytes_done);
            #1;
            for (byte_idx = 0; byte_idx < 32; byte_idx = byte_idx + 1) begin
                if (bytes_seq_out[byte_idx] !== bytes_ref_out[byte_idx]) begin
                    $display("FAIL bytes case=%0d byte=%0d seq=%02x ref=%02x", case_idx, byte_idx,
                             bytes_seq_out[byte_idx], bytes_ref_out[byte_idx]);
                    $fatal(1);
                end
            end
            @(posedge clk);
        end
    endtask

    initial begin
        carry_start = 1'b0;
        bytes_start = 1'b0;
        carry_in = 512'd0;
        bytes_in = 320'd0;
        lfsr = 32'h1ace_b00c;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (case_idx = 0; case_idx < 24; case_idx = case_idx + 1) begin
            for (byte_idx = 0; byte_idx < 64; byte_idx = byte_idx + 1) begin
                lfsr = next_lfsr(lfsr);
                carry_in[511 - 8*byte_idx -: 8] = lfsr[7:0];
            end
            run_carry_case();
        end

        for (case_idx = 0; case_idx < 24; case_idx = case_idx + 1) begin
            for (limb_idx = 0; limb_idx < 10; limb_idx = limb_idx + 1) begin
                lfsr = next_lfsr(lfsr);
                bytes_in[32*limb_idx +: 32] = {8{lfsr[3:0]}} ^ lfsr;
            end
            run_bytes_case();
        end

        $display("PASS tb_saif_seq_optimizations");
        $finish;
    end
endmodule
