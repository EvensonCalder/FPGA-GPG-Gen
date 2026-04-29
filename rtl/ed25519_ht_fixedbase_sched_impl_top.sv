`timescale 1ns / 1ps

import ed25519_ht_fe17_pkg::*;

module ed25519_ht_fixedbase_sched_impl_top #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer CONTEXTS = 16,
    parameter integer TAG_WIDTH = 4
) (
    input  logic clk,
    input  logic rst_n,
    output logic sink
);
    logic scalar_valid;
    logic scalar_ready;
    logic [255:0] scalar_q;
    logic [TAG_WIDTH-1:0] scalar_tag_q;
    logic point_valid;
    logic [TAG_WIDTH-1:0] point_tag;
    fe17_t point_x, point_y, point_z;

    assign scalar_valid = rst_n;

    ed25519_ht_fixedbase_sched #(
        .INIT_FILE(INIT_FILE),
        .CONTEXTS(CONTEXTS),
        .TAG_WIDTH(TAG_WIDTH)
    ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        .scalar_valid(scalar_valid),
        .scalar_ready(scalar_ready),
        .scalar(scalar_q),
        .scalar_tag(scalar_tag_q),
        .point_valid(point_valid),
        .point_ready(1'b1),
        .point_tag(point_tag),
        .point_x(point_x),
        .point_y(point_y),
        .point_z(point_z)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scalar_q <= 256'h6f8eff1f84f125a1e612dede40146d9d5549e02b76356981ef0a589ca4ee9438;
            scalar_tag_q <= '0;
            sink <= 1'b0;
        end else begin
            if (scalar_valid && scalar_ready) begin
                scalar_q <= {scalar_q[254:0], scalar_q[255] ^ scalar_q[21] ^ scalar_q[1] ^ scalar_q[0]};
                scalar_tag_q <= scalar_tag_q + 1'b1;
            end

            if (point_valid)
                sink <= sink ^ ^{point_x, point_y, point_z, point_tag};
        end
    end
endmodule
