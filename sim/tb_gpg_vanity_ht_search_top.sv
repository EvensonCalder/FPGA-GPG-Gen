`timescale 1ns / 1ps

module tb_gpg_vanity_ht_search_top #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
);
    localparam logic [255:0] FIRST_SEED = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
    localparam logic [255:0] EXPECTED_PUBLIC = 256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103;
    localparam int FRAME_LEN = 74;
    localparam int HB_FRAME_LEN = 26;
    localparam int CLKS_PER_BIT = 5;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic uart_tx;
    byte frame [0:FRAME_LEN-1];

    always #5 clk = ~clk;

    gpg_vanity_ht_search_top #(
        .CLK_HZ(50000000),
        .BAUD(10000000),
        .HB_PERIOD(500000),
        .TIMESTAMP(32'd1700000000),
        .INIT_FILE(INIT_FILE),
        .LANES(1),
        .MUL_LANES(1),
        .NATIVE_COMPRESS(1'b0),
        .BATCH_COMPRESS(1'b0),
        .MULTI_CONTEXT_SCALAR(1'b0),
        .DEBUG_ACCEPT_ALL(1'b1),
        .SIM_SEED_MODE(1'b1),
        .SIM_SEED_START(FIRST_SEED)
    ) dut (
        .clk_50m(clk),
        .key2_reset_n(rst_n),
        .uart_tx(uart_tx)
    );

    function automatic [31:0] crc32_update_byte(input [31:0] crc_in, input [7:0] data);
        integer bit_idx;
        reg [31:0] crc;
        begin
            crc = crc_in ^ {24'd0, data};
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                if (crc[0])
                    crc = (crc >> 1) ^ 32'hedb88320;
                else
                    crc = crc >> 1;
            end
            crc32_update_byte = crc;
        end
    endfunction

    function automatic [31:0] crc32_body(input int body_end_idx);
        integer i;
        reg [31:0] crc;
        begin
            crc = 32'hffffffff;
            for (i = 5; i < body_end_idx; i = i + 1)
                crc = crc32_update_byte(crc, frame[i]);
            crc32_body = ~crc;
        end
    endfunction

    task automatic read_uart_byte(output byte value);
        int bit_idx;
        begin
            @(negedge uart_tx);
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);
            #1;
            value[0] = uart_tx;
            for (bit_idx = 1; bit_idx < 8; bit_idx = bit_idx + 1) begin
                repeat (CLKS_PER_BIT) @(posedge clk);
                #1;
                value[bit_idx] = uart_tx;
            end
            repeat (CLKS_PER_BIT) @(posedge clk);
            #1;
            if (uart_tx !== 1'b1)
                $fatal(1, "bad UART stop bit");
        end
    endtask

    task automatic check_hit_frame;
        int i;
        logic [31:0] exp_crc;
        logic [31:0] got_crc;
        begin
            if ({frame[0], frame[1], frame[2], frame[3], frame[4]} !== 40'h4750475631)
                $fatal(1, "bad magic %02x %02x %02x %02x %02x", frame[0], frame[1], frame[2], frame[3], frame[4]);
            if (frame[5] !== 8'd0)
                $fatal(1, "bad class_id %0d", frame[5]);
            for (i = 0; i < 32; i = i + 1) begin
                if (frame[6 + i] !== FIRST_SEED[i * 8 +: 8])
                    $fatal(1, "seed byte mismatch idx=%0d got=%02x expected=%02x", i, frame[6 + i], FIRST_SEED[i * 8 +: 8]);
                if (frame[38 + i] !== EXPECTED_PUBLIC[i * 8 +: 8])
                    $fatal(1, "public byte mismatch idx=%0d got=%02x expected=%02x", i, frame[38 + i], EXPECTED_PUBLIC[i * 8 +: 8]);
            end
            exp_crc = crc32_body(70);
            got_crc = {frame[73], frame[72], frame[71], frame[70]};
            if (got_crc !== exp_crc)
                $fatal(1, "hit crc mismatch got=%08x expected=%08x", got_crc, exp_crc);
        end
    endtask

    task automatic check_hb_frame;
        logic [31:0] exp_crc;
        logic [31:0] got_crc;
        int i;
        begin
            if ({frame[0], frame[1], frame[2], frame[3], frame[4]} !== 40'h4750475631)
                $fatal(1, "hb bad magic");
            if (frame[5] !== 8'hFE)
                $fatal(1, "hb bad class_id %02x", frame[5]);
            exp_crc = crc32_body(HB_FRAME_LEN - 4);
            got_crc = {frame[25], frame[24], frame[23], frame[22]};
            if (got_crc !== exp_crc)
                $fatal(1, "hb crc mismatch got=%08x expected=%08x", got_crc, exp_crc);
        end
    endtask

    task automatic read_until_hb_frame(output int skipped_frames);
        byte b;
        logic [39:0] window;
        begin
            skipped_frames = 0;
            window = 40'd0;
            forever begin
                read_uart_byte(b);
                window = {window[31:0], b};
                if (window == 40'h4750475631) begin
                    frame[0] = 8'h47;
                    frame[1] = 8'h50;
                    frame[2] = 8'h47;
                    frame[3] = 8'h56;
                    frame[4] = 8'h31;
                    read_uart_byte(frame[5]);
                    if (frame[5] == 8'hFE) begin
                        for (int i = 6; i < HB_FRAME_LEN; i = i + 1)
                            read_uart_byte(frame[i]);
                        return;
                    end
                    for (int i = 6; i < FRAME_LEN; i = i + 1)
                        read_uart_byte(frame[i]);
                    skipped_frames = skipped_frames + 1;
                    window = 40'd0;
                end
            end
        end
    endtask

    initial begin
        int frame_count;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        // frame 0: hit from DEBUG_ACCEPT_ALL
        for (int i = 0; i < FRAME_LEN; i = i + 1)
            read_uart_byte(frame[i]);
        check_hit_frame();
        $display("PASS hit frame");

        read_until_hb_frame(frame_count);
        $display("PASS heartbeat frame (after %0d frames)", frame_count);
        check_hb_frame();

        $display("PASS tb_gpg_vanity_ht_search_top");
        $finish;
    end

    initial begin
        repeat (100_000_000) @(posedge clk);
        $fatal(1, "timeout waiting for UART frames");
    end
endmodule
