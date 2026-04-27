`timescale 1ns / 1ps

module tb_ed25519_scalar_recode_4bit;
    logic [255:0] scalar;
    logic signed [7:0] digit [0:63];

    ed25519_scalar_recode_4bit dut (
        .scalar(scalar),
        .digit(digit)
    );

    task automatic check_scalar(input logic [255:0] scalar_value);
        logic signed [264:0] acc;
        logic signed [264:0] term;
        begin
            scalar = scalar_value;
            #1;

            acc = 265'sd0;
            for (int i = 0; i < 64; i++) begin
                if (digit[i] < -8 || digit[i] > 8) begin
                    $fatal(1, "digit[%0d]=%0d out of range", i, digit[i]);
                end
                term = {{257{digit[i][7]}}, digit[i]};
                acc = acc + (term <<< (4*i));
            end

            if (acc[255:0] !== scalar_value || acc[264:256] !== 9'd0) begin
                $fatal(1, "recode mismatch scalar=%064x acc=%067x", scalar_value, acc);
            end
        end
    endtask

    initial begin
        check_scalar(256'h0000000000000000000000000000000000000000000000000000000000000000);
        check_scalar(256'h0000000000000000000000000000000000000000000000000000000000000001);
        check_scalar(256'h4000000000000000000000000000000000000000000000000000000000000000);
        check_scalar(256'h5f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020140);
        check_scalar(256'h607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db16158);

        for (int i = 0; i < 100; i++) begin
            scalar = {$urandom(), $urandom(), $urandom(), $urandom(),
                      $urandom(), $urandom(), $urandom(), $urandom()};
            scalar[255] = 1'b0;
            check_scalar(scalar);
        end

        $display("PASS tb_ed25519_scalar_recode_4bit");
        $finish;
    end
endmodule
