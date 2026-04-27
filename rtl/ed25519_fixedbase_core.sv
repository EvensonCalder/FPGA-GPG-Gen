`timescale 1ns / 1ps

module ed25519_fixedbase_core (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [255:0] scalar,
    output logic signed [319:0] r_X,
    output logic signed [319:0] r_Y,
    output logic signed [319:0] r_Z,
    output logic signed [319:0] r_T,
    output logic         done
);
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_START,
        ST_BUSY
    } state_t;

    state_t state;
    logic         ctx_start;
    logic         ctx_done;
    logic [255:0] scalar_reg;

    assign ctx_start = (state == ST_START);
    assign done = ctx_done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            scalar_reg <= 256'd0;
        end else begin
            unique case (state)
                ST_IDLE: begin
                    if (start) begin
                        scalar_reg <= scalar;
                        state <= ST_START;
                    end
                end

                ST_START: begin
                    state <= ST_BUSY;
                end

                ST_BUSY: begin
                    if (ctx_done)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    ed25519_fixedbase_context_v2_shared u_fixedbase (
        .clk(clk),
        .rst_n(rst_n),
        .start(ctx_start),
        .scalar(scalar_reg),
        .r_X(r_X),
        .r_Y(r_Y),
        .r_Z(r_Z),
        .r_T(r_T),
        .done(ctx_done)
    );
endmodule
