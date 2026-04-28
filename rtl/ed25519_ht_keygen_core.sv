`timescale 1ns / 1ps

module ed25519_ht_keygen_core #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem",
    parameter integer MUL_LANES = 1
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] seed,
    output logic         busy,
    output logic         done,
    output logic [255:0] seed_out,
    output logic [511:0] expanded_secret,
    output logic [255:0] public_key
);
    typedef enum logic [2:0] {
        ST_IDLE       = 3'd0,
        ST_HASH       = 3'd1,
        ST_SCALARMULT = 3'd2,
        ST_TOBYTES    = 3'd3,
        ST_DONE       = 3'd4
    } state_t;

    state_t state, prev_state;
    logic [255:0] seed_reg;
    logic [511:0] hash_out;
    logic [511:0] clamped_secret;
    logic hash_done;
    logic ge_done;
    logic tobytes_done;
    logic start_hash;
    logic start_ge;
    logic start_tobytes;

    logic signed [319:0] ge_x;
    logic signed [319:0] ge_y;
    logic signed [319:0] ge_z;
    logic signed [319:0] ge_t;
    logic [7:0] public_bytes [31:0];

    assign busy = (state != ST_IDLE) && (state != ST_DONE);

    SHA512_wrapper_mux u_sha512_wrapper (
        .clk(clk), .rst(rst_n), .start_sha512(start_hash),
        .sha512_mode(2'b00), .hash_message_in(512'd0), .random_number(seed_reg),
        .hash_pubkey_in(256'd0), .R(256'd0), .seckey32_in(256'd0),
        .end_sha512(hash_done), .hash(hash_out)
    );

    seckey_clamp u_seckey_clamp (
        .input_hashed_seckey(hash_out),
        .output_sk(clamped_secret)
    );

    ed25519_ht_fixedbase_core #(
        .INIT_FILE(INIT_FILE),
        .MUL_LANES(MUL_LANES)
    ) u_fixedbase_core (
        .clk(clk), .rst_n(rst_n), .start(start_ge),
        .scalar(clamped_secret[255:0]),
        .r_X(ge_x), .r_Y(ge_y), .r_Z(ge_z), .r_T(ge_t),
        .done(ge_done)
    );

    ge_p3_tobytes u_tobytes (
        .clk(clk), .rst(rst_n), .start(start_tobytes),
        .X(ge_x), .Y(ge_y), .Z(ge_z), .s(public_bytes), .done(tobytes_done)
    );

    always_comb begin
        start_hash = (state == ST_HASH) && (prev_state != ST_HASH);
        start_ge = (state == ST_SCALARMULT) && (prev_state != ST_SCALARMULT);
        start_tobytes = (state == ST_TOBYTES) && (prev_state != ST_TOBYTES);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            prev_state <= ST_IDLE;
            seed_reg <= 256'd0;
            seed_out <= 256'd0;
            expanded_secret <= 512'd0;
            public_key <= 256'd0;
            done <= 1'b0;
        end else begin
            prev_state <= state;
            done <= 1'b0;

            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        seed_reg <= seed;
                        state <= ST_HASH;
                    end
                end
                ST_HASH: begin
                    if (hash_done) begin
                        expanded_secret <= clamped_secret;
                        state <= ST_SCALARMULT;
                    end
                end
                ST_SCALARMULT: begin
                    if (ge_done)
                        state <= ST_TOBYTES;
                end
                ST_TOBYTES: begin
                    if (tobytes_done) begin
                        public_key <= {public_bytes[31], public_bytes[30], public_bytes[29], public_bytes[28],
                                       public_bytes[27], public_bytes[26], public_bytes[25], public_bytes[24],
                                       public_bytes[23], public_bytes[22], public_bytes[21], public_bytes[20],
                                       public_bytes[19], public_bytes[18], public_bytes[17], public_bytes[16],
                                       public_bytes[15], public_bytes[14], public_bytes[13], public_bytes[12],
                                       public_bytes[11], public_bytes[10], public_bytes[9],  public_bytes[8],
                                       public_bytes[7],  public_bytes[6],  public_bytes[5],  public_bytes[4],
                                       public_bytes[3],  public_bytes[2],  public_bytes[1],  public_bytes[0]};
                        seed_out <= seed_reg;
                        state <= ST_DONE;
                    end
                end
                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
