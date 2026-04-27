`timescale 1ns / 1ps

module tb_gpg_vanity_pattern_matcher;
    logic [159:0] fingerprint;
    logic hit;
    logic [3:0] class_id;

    gpg_vanity_pattern_matcher dut (
        .fingerprint(fingerprint),
        .hit(hit),
        .class_id(class_id)
    );

    task automatic check_case;
        input [159:0] fp;
        input exp_hit;
        input [3:0] exp_class;
        begin
            fingerprint = fp;
            #1;
            if (hit !== exp_hit || (exp_hit && class_id !== exp_class)) begin
                $display("FAIL fp=%040h hit=%0d class=%0h expected_hit=%0d expected_class=%0h",
                         fp, hit, class_id, exp_hit, exp_class);
                $fatal(1);
            end
        end
    endtask

    initial begin
        check_case(160'haaaaaaaa0123456789abcdef0123456789abcdef, 1'b1, 4'h1);
        check_case(160'h0123456789abcdef0123456789abcdef77777777, 1'b1, 4'h0);
        check_case(160'hffffffff0123456789abcdef0123456700000000, 1'b1, 4'h0);
        check_case(160'h0123456789abcdef0123456789abcdef01234567, 1'b0, 4'h0);
        $display("PASS tb_gpg_vanity_pattern_matcher");
        $finish;
    end
endmodule
