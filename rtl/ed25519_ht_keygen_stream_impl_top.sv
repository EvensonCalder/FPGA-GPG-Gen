`timescale 1ns / 1ps

module ed25519_ht_keygen_stream_impl_top #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1
) (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] produced_count_low,
    output logic [31:0] public_xor_low
);
    logic seed_valid;
    logic seed_ready;
    logic [255:0] seed;
    logic out_valid;
    logic [255:0] out_seed;
    logic [255:0] out_public_key;
    logic [63:0] accepted_count;
    logic [63:0] produced_count;
    logic [63:0] stall_seed_count;
    logic [63:0] stall_output_count;
    logic [255:0] public_xor;

    assign seed_valid = 1'b1;
    assign produced_count_low = produced_count[31:0];
    assign public_xor_low = public_xor[31:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seed <= 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
            public_xor <= 256'd0;
        end else begin
            if (seed_valid && seed_ready)
                seed <= seed + 256'd1;
            if (out_valid)
                public_xor <= public_xor ^ out_public_key ^ out_seed;
        end
    end

    ed25519_ht_keygen_stream #(
        .INIT_FILE(INIT_FILE),
        .MUL_LANES(MUL_LANES)
    ) u_stream (
        .clk(clk),
        .rst_n(rst_n),
        .seed_valid(seed_valid),
        .seed_ready(seed_ready),
        .seed(seed),
        .out_valid(out_valid),
        .out_ready(1'b1),
        .out_seed(out_seed),
        .out_public_key(out_public_key),
        .accepted_count(accepted_count),
        .produced_count(produced_count),
        .stall_seed_count(stall_seed_count),
        .stall_output_count(stall_output_count)
    );
endmodule
