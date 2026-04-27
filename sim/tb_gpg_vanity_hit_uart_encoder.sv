`timescale 1ns / 1ps

module tb_gpg_vanity_hit_uart_encoder;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic hit_valid;
    logic hit_ready;
    logic [3:0] hit_class_id;
    logic [255:0] hit_seed;
    logic [255:0] hit_public_key;
    logic [7:0] uart_data;
    logic uart_valid;
    logic uart_ready;

    logic [7:0] expected [0:73];
    integer i;
    integer idx;

    always #5 clk = ~clk;

    gpg_vanity_hit_uart_encoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .hit_valid(hit_valid),
        .hit_ready(hit_ready),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .uart_data(uart_data),
        .uart_valid(uart_valid),
        .uart_ready(uart_ready)
    );

    initial begin
        expected[0] = 8'h47;
        expected[1] = 8'h50;
        expected[2] = 8'h47;
        expected[3] = 8'h56;
        expected[4] = 8'h31;
        expected[5] = 8'h01;
        for (i = 0; i < 32; i = i + 1)
            expected[6 + i] = i[7:0];
        for (i = 0; i < 32; i = i + 1)
            expected[38 + i] = (8'ha0 + i[7:0]);
        expected[70] = 8'hce;
        expected[71] = 8'hef;
        expected[72] = 8'hd4;
        expected[73] = 8'hbd;

        hit_valid = 1'b0;
        hit_class_id = 4'h1;
        hit_seed = 256'd0;
        hit_public_key = 256'd0;
        uart_ready = 1'b0;
        idx = 0;

        for (i = 0; i < 32; i = i + 1)
            hit_seed[i * 8 +: 8] = i[7:0];
        for (i = 0; i < 32; i = i + 1)
            hit_public_key[i * 8 +: 8] = (8'ha0 + i[7:0]);

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        if (!hit_ready)
            $fatal(1, "encoder not ready after reset");

        hit_valid = 1'b1;
        @(posedge clk);
        #1;
        hit_valid = 1'b0;

        while (idx < 74) begin
            wait (uart_valid);
            #1;
            if (uart_data !== expected[idx]) begin
                $display("FAIL byte[%0d]=%02x expected=%02x", idx, uart_data, expected[idx]);
                $fatal(1);
            end
            uart_ready = 1'b1;
            @(posedge clk);
            #1;
            uart_ready = 1'b0;
            idx = idx + 1;
        end

        @(posedge clk);
        if (!hit_ready)
            $fatal(1, "encoder did not return to ready");
        $display("PASS tb_gpg_vanity_hit_uart_encoder");
        $finish;
    end
endmodule
