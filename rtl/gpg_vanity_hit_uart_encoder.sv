`timescale 1ns / 1ps

module gpg_vanity_hit_uart_encoder (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         hit_valid,
    output logic         hit_ready,
    input  logic [3:0]   hit_class_id,
    input  logic [255:0] hit_seed,
    input  logic [255:0] hit_public_key,
    output logic [7:0]   uart_data,
    output logic         uart_valid,
    input  logic         uart_ready
);
    localparam int FRAME_LEN = 74;

    typedef enum logic [0:0] {
        ST_IDLE = 1'b0,
        ST_SEND = 1'b1
    } state_t;

    state_t state;
    logic [6:0] byte_index;
    logic [3:0] class_reg;
    logic [255:0] seed_reg;
    logic [255:0] public_key_reg;
    logic [31:0] crc_reg;

    assign hit_ready = (state == ST_IDLE);
    assign uart_valid = (state == ST_SEND);

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

    function automatic [7:0] body_byte;
        input [6:0] idx;
        input [3:0] class_id;
        input [255:0] seed;
        input [255:0] public_key;
        begin
            if (idx == 7'd0)
                body_byte = {4'd0, class_id};
            else if (idx < 7'd33)
                body_byte = seed[(idx - 7'd1) * 8 +: 8];
            else
                body_byte = public_key[(idx - 7'd33) * 8 +: 8];
        end
    endfunction

    function automatic [31:0] crc32_body;
        input [3:0] class_id;
        input [255:0] seed;
        input [255:0] public_key;
        integer i;
        reg [31:0] crc;
        begin
            crc = 32'hffffffff;
            for (i = 0; i < 65; i = i + 1)
                crc = crc32_update_byte(crc, body_byte(i[6:0], class_id, seed, public_key));
            crc32_body = ~crc;
        end
    endfunction

    function automatic [7:0] frame_byte;
        input [6:0] idx;
        input [3:0] class_id;
        input [255:0] seed;
        input [255:0] public_key;
        input [31:0] crc;
        begin
            case (idx)
                7'd0: frame_byte = 8'h47; // G
                7'd1: frame_byte = 8'h50; // P
                7'd2: frame_byte = 8'h47; // G
                7'd3: frame_byte = 8'h56; // V
                7'd4: frame_byte = 8'h31; // 1
                7'd5: frame_byte = {4'd0, class_id};
                default: begin
                    if (idx < 7'd38)
                        frame_byte = seed[(idx - 7'd6) * 8 +: 8];
                    else if (idx < 7'd70)
                        frame_byte = public_key[(idx - 7'd38) * 8 +: 8];
                    else
                        frame_byte = crc[(idx - 7'd70) * 8 +: 8];
                end
            endcase
        end
    endfunction

    always_comb begin
        uart_data = frame_byte(byte_index, class_reg, seed_reg, public_key_reg, crc_reg);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            byte_index <= 7'd0;
            class_reg <= 4'd0;
            seed_reg <= 256'd0;
            public_key_reg <= 256'd0;
            crc_reg <= 32'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    byte_index <= 7'd0;
                    if (hit_valid) begin
                        class_reg <= hit_class_id;
                        seed_reg <= hit_seed;
                        public_key_reg <= hit_public_key;
                        crc_reg <= crc32_body(hit_class_id, hit_seed, hit_public_key);
                        state <= ST_SEND;
                    end
                end

                ST_SEND: begin
                    if (uart_ready) begin
                        if (byte_index == FRAME_LEN - 1) begin
                            byte_index <= 7'd0;
                            state <= ST_IDLE;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
