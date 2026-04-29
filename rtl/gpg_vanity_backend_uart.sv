`timescale 1ns / 1ps

module gpg_vanity_backend_uart #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD   = 2000000,
    parameter DEBUG_ACCEPT_ALL = 1'b0,
    parameter MATCH_SUFFIX = 1'b1,
    parameter MATCH_PREFIX = 1'b1
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [31:0]  timestamp,
    input  logic         candidate_valid,
    output logic         candidate_ready,
    input  logic [255:0] candidate_seed,
    input  logic [255:0] candidate_public_key,
    input  logic [63:0]  produced_count,
    input  logic [63:0]  accepted_count,
    input  logic [63:0]  stall_seed_count,
    input  logic [63:0]  stall_output_count,
    output logic         uart_tx
);
    logic hit_valid;
    logic hit_ready;
    logic filter_candidate_ready;
    logic [3:0] hit_class_id;
    logic [255:0] hit_seed;
    logic [255:0] hit_public_key;
    logic [159:0] hit_fingerprint;
    logic hit_uart_tx;

    assign candidate_ready = filter_candidate_ready && hit_ready;

    gpg_vanity_filter #(
        .DEBUG_ACCEPT_ALL(DEBUG_ACCEPT_ALL),
        .MATCH_SUFFIX(MATCH_SUFFIX),
        .MATCH_PREFIX(MATCH_PREFIX)
    ) u_filter (
        .clk(clk),
        .rst_n(rst_n),
        .timestamp(timestamp),
        .candidate_valid(candidate_valid && hit_ready),
        .candidate_ready(filter_candidate_ready),
        .seed(candidate_seed),
        .public_key(candidate_public_key),
        .hit_valid(hit_valid),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .hit_fingerprint(hit_fingerprint)
    );

    gpg_vanity_hit_uart #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_hit_uart (
        .clk(clk),
        .rst_n(rst_n),
        .hit_valid(hit_valid),
        .hit_ready(hit_ready),
        .hit_class_id(hit_class_id),
        .hit_seed(hit_seed),
        .hit_public_key(hit_public_key),
        .uart_tx(hit_uart_tx)
    );

    // ── Heartbeat status frame every ~1 second ──────────────────────────
    localparam int HB_FRAME_LEN = 74;
    localparam int HB_CYCLES    = CLK_HZ;

    typedef enum logic [0:0] {
        HB_IDLE = 1'b0,
        HB_SEND = 1'b1
    } hb_state_t;

    hb_state_t       hb_state;
    logic [31:0]     hb_timer;
    logic [6:0]      hb_byte_idx;
    logic [31:0]     hb_crc;
    logic [7:0]      hb_data;
    logic            hb_valid;
    logic            hb_ready;
    logic            hb_tx;
    logic            hb_pending;

    function automatic [31:0] crc32_update_byte;
        input [31:0] crc_in;
        input [7:0] data;
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

    function automatic [31:0] crc32_body;
        input [6:0] count;
        reg [31:0] crc;
        integer i;
        begin
            crc = 32'hffffffff;
            for (i = 5; i < count; i = i + 1)
                crc = crc32_update_byte(crc, hb_frame_byte(i));
            crc32_body = ~crc;
        end
    endfunction

    function automatic [7:0] hb_frame_byte;
        input [6:0] idx;
        begin
            case (idx)
                7'd0:    hb_frame_byte = 8'h47;   // 'G'
                7'd1:    hb_frame_byte = 8'h50;   // 'P'
                7'd2:    hb_frame_byte = 8'h47;   // 'G'
                7'd3:    hb_frame_byte = 8'h56;   // 'V'
                7'd4:    hb_frame_byte = 8'h31;   // '1'
                7'd5:    hb_frame_byte = 8'hFE;   // heartbeat class_id
                7'd6:    hb_frame_byte = produced_count[63:56];
                7'd7:    hb_frame_byte = produced_count[55:48];
                7'd8:    hb_frame_byte = produced_count[47:40];
                7'd9:    hb_frame_byte = produced_count[39:32];
                7'd10:   hb_frame_byte = produced_count[31:24];
                7'd11:   hb_frame_byte = produced_count[23:16];
                7'd12:   hb_frame_byte = produced_count[15:8];
                7'd13:   hb_frame_byte = produced_count[7:0];
                7'd14:   hb_frame_byte = accepted_count[63:56];
                7'd15:   hb_frame_byte = accepted_count[55:48];
                7'd16:   hb_frame_byte = accepted_count[47:40];
                7'd17:   hb_frame_byte = accepted_count[39:32];
                7'd18:   hb_frame_byte = accepted_count[31:24];
                7'd19:   hb_frame_byte = accepted_count[23:16];
                7'd20:   hb_frame_byte = accepted_count[15:8];
                7'd21:   hb_frame_byte = accepted_count[7:0];
                7'd22:   hb_frame_byte = stall_seed_count[63:56];
                7'd23:   hb_frame_byte = stall_seed_count[55:48];
                7'd24:   hb_frame_byte = stall_seed_count[47:40];
                7'd25:   hb_frame_byte = stall_seed_count[39:32];
                7'd26:   hb_frame_byte = stall_seed_count[31:24];
                7'd27:   hb_frame_byte = stall_seed_count[23:16];
                7'd28:   hb_frame_byte = stall_seed_count[15:8];
                7'd29:   hb_frame_byte = stall_seed_count[7:0];
                7'd30:   hb_frame_byte = stall_output_count[63:56];
                7'd31:   hb_frame_byte = stall_output_count[55:48];
                7'd32:   hb_frame_byte = stall_output_count[47:40];
                7'd33:   hb_frame_byte = stall_output_count[39:32];
                7'd34:   hb_frame_byte = stall_output_count[31:24];
                7'd35:   hb_frame_byte = stall_output_count[23:16];
                7'd36:   hb_frame_byte = stall_output_count[15:8];
                7'd37:   hb_frame_byte = stall_output_count[7:0];
                7'd38..7'd69: hb_frame_byte = 8'd0;  // public key zero-pad
                7'd70:   hb_frame_byte = hb_crc[7:0];
                7'd71:   hb_frame_byte = hb_crc[15:8];
                7'd72:   hb_frame_byte = hb_crc[23:16];
                7'd73:   hb_frame_byte = hb_crc[31:24];
                default: hb_frame_byte = 8'd0;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hb_state    <= HB_IDLE;
            hb_timer    <= 32'd0;
            hb_byte_idx <= 7'd0;
            hb_crc      <= 32'd0;
            hb_pending  <= 1'b0;
        end else begin
            if (!hb_pending && hb_timer >= (HB_CYCLES - 1)) begin
                hb_timer   <= 32'd0;
                hb_pending <= 1'b1;
            end else begin
                hb_timer <= hb_timer + 1'b1;
            end

            case (hb_state)
                HB_IDLE: begin
                    if (hb_pending && hit_ready && hb_ready) begin
                        hb_state    <= HB_SEND;
                        hb_byte_idx <= 7'd5;
                        hb_crc      <= 32'hffffffff;
                        hb_pending  <= 1'b0;
                    end
                end
                HB_SEND: begin
                    if (hb_valid && hb_ready) begin
                        hb_crc <= crc32_update_byte(hb_crc, hb_data);
                        if (hb_byte_idx == 7'd69)
                            hb_byte_idx <= hb_byte_idx + 1'b1;  // CRC bytes
                        else if (hb_byte_idx == 7'd73)
                            hb_state <= HB_IDLE;
                        else
                            hb_byte_idx <= hb_byte_idx + 1'b1;
                    end
                end
            endcase
        end
    end

    assign hb_data  = (hb_state == HB_SEND) ? hb_frame_byte(hb_byte_idx) : 8'd0;
    assign hb_valid = (hb_state == HB_SEND);

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_hb_uart (
        .clk(clk),
        .rst_n(rst_n),
        .data(hb_data),
        .valid(hb_valid),
        .ready(hb_ready),
        .tx(hb_tx)
    );

    assign uart_tx = (hb_state == HB_SEND) ? hb_tx : hit_uart_tx;
endmodule
