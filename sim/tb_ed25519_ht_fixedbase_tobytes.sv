`timescale 1ns / 1ps

module tb_ed25519_ht_fixedbase_tobytes #(
    parameter string INIT_FILE = "build/ht_fixedbase_table.mem"
);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #2 clk = ~clk;

    logic start_fb, done_fb;
    logic done_ref_fb;
    logic start_tb, done_tb;
    logic start_ref_tb, done_ref_tb;
    logic [255:0] scalar;
    logic signed [319:0] x, y, z, t;
    logic signed [319:0] ref_x, ref_y, ref_z, ref_t;
    fe17_t cx, cy, cz, ct;
    logic [7:0] public_bytes [31:0];
    logic [7:0] ref_public_bytes [31:0];
    logic [255:0] public_key;
    logic [255:0] ref_public_key;

    ed25519_ht_fixedbase_core #(
        .INIT_FILE(INIT_FILE)
    ) u_fb (
        .clk(clk), .rst_n(rst_n), .start(start_fb), .scalar(scalar),
        .r_X(x), .r_Y(y), .r_Z(z), .r_T(t), .done(done_fb)
    );

    ed25519_ht_fixedbase_context #(
        .INIT_FILE(INIT_FILE)
    ) u_ctx_dbg (
        .clk(clk), .rst_n(rst_n), .start(start_fb), .scalar(scalar),
        .r_X(cx), .r_Y(cy), .r_Z(cz), .r_T(ct), .done()
    );

    ge_p3_tobytes u_tobytes (
        .clk(clk), .rst(rst_n), .start(start_tb),
        .X(x), .Y(y), .Z(z), .s(public_bytes), .done(done_tb)
    );

    ed25519_fixedbase_context_v2_shared u_ref_fb (
        .clk(clk), .rst_n(rst_n), .start(start_fb), .scalar(scalar),
        .r_X(ref_x), .r_Y(ref_y), .r_Z(ref_z), .r_T(ref_t), .done(done_ref_fb)
    );

    ge_p3_tobytes u_ref_tobytes (
        .clk(clk), .rst(rst_n), .start(start_ref_tb),
        .X(ref_x), .Y(ref_y), .Z(ref_z), .s(ref_public_bytes), .done(done_ref_tb)
    );

    always_comb begin
        public_key = {public_bytes[31], public_bytes[30], public_bytes[29], public_bytes[28],
                      public_bytes[27], public_bytes[26], public_bytes[25], public_bytes[24],
                      public_bytes[23], public_bytes[22], public_bytes[21], public_bytes[20],
                      public_bytes[19], public_bytes[18], public_bytes[17], public_bytes[16],
                      public_bytes[15], public_bytes[14], public_bytes[13], public_bytes[12],
                      public_bytes[11], public_bytes[10], public_bytes[9],  public_bytes[8],
                      public_bytes[7],  public_bytes[6],  public_bytes[5],  public_bytes[4],
                      public_bytes[3],  public_bytes[2],  public_bytes[1],  public_bytes[0]};
        ref_public_key = {ref_public_bytes[31], ref_public_bytes[30], ref_public_bytes[29], ref_public_bytes[28],
                          ref_public_bytes[27], ref_public_bytes[26], ref_public_bytes[25], ref_public_bytes[24],
                          ref_public_bytes[23], ref_public_bytes[22], ref_public_bytes[21], ref_public_bytes[20],
                          ref_public_bytes[19], ref_public_bytes[18], ref_public_bytes[17], ref_public_bytes[16],
                          ref_public_bytes[15], ref_public_bytes[14], ref_public_bytes[13], ref_public_bytes[12],
                          ref_public_bytes[11], ref_public_bytes[10], ref_public_bytes[9],  ref_public_bytes[8],
                          ref_public_bytes[7],  ref_public_bytes[6],  ref_public_bytes[5],  ref_public_bytes[4],
                          ref_public_bytes[3],  ref_public_bytes[2],  ref_public_bytes[1],  ref_public_bytes[0]};
    end

    task automatic run_case(input logic [255:0] scalar_value, input logic [255:0] expected_public);
        int cycles;
        begin
            scalar = scalar_value;
            @(negedge clk); start_fb = 1'b1;
            @(negedge clk); start_fb = 1'b0;
            cycles = 0;
            while (!done_fb && cycles < 100000) begin @(posedge clk); cycles++; end
            if (!done_fb) $fatal(1, "fixedbase timeout");
            while (!done_ref_fb && cycles < 100000) begin @(posedge clk); cycles++; end
            if (!done_ref_fb) $fatal(1, "ref fixedbase timeout");
            #1;
            $display("fixedbase cycles=%0d cx=%064x cy=%064x cz=%064x X=%080x Y=%080x Z=%080x refX=%080x refY=%080x refZ=%080x", cycles, cx, cy, cz, x, y, z, ref_x, ref_y, ref_z);

            @(negedge clk); start_tb = 1'b1; start_ref_tb = 1'b1;
            @(negedge clk); start_tb = 1'b0; start_ref_tb = 1'b0;
            cycles = 0;
            while (!(done_tb && done_ref_tb) && cycles < 100000) begin @(posedge clk); cycles++; end
            if (!done_tb) $fatal(1, "tobytes timeout");
            if (!done_ref_tb) $fatal(1, "ref tobytes timeout");
            #1;
            $display("ht_public=%064x ref_public=%064x", public_key, ref_public_key);
            if (public_key !== expected_public)
                $fatal(1, "public mismatch got=%064x expected=%064x cycles=%0d", public_key, expected_public, cycles);
            $display("PASS fixedbase_tobytes public=%064x cycles=%0d", public_key, cycles);
        end
    endtask

    initial begin
        start_fb = 1'b0;
        start_tb = 1'b0;
        start_ref_tb = 1'b0;
        scalar = 256'd0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        run_case(
            256'h6f8eff1f84f125a1e612dede40146d9d5549e02b76356981ef0a589ca4ee9438,
            256'hb83155126486dc1d5f0da59b30d6e46799c04be718dd701dbe10cef3bf07a103
        );
        $display("PASS tb_ed25519_ht_fixedbase_tobytes");
        $finish;
    end
endmodule
