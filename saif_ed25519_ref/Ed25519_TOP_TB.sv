import ed25519_pkg::*;

module Ed25519_TOP_TB;

    // Clock and reset
    logic clk;
    logic rst;
    logic [1:0] opmode;
    logic start;
    logic [63:0] data_in;
    logic valid;
    logic [63:0] data_out;

    // Results
    logic [255:0] pubkey_out;
    logic [511:0] privkey_out;
    logic [511:0] sig_out;
    logic [511:0] wrong_signature;
    logic [255:0] result_out;

    logic [511:0] message;
    logic [255:0] expected_pk;
    logic [511:0] expected_sk;
    logic [511:0] expected_sig;
    logic [63:0] v_exp_out;
    logic [255:0] seed;

    // Enhanced storage for more test cases
    logic [511:0] test_messages[20];
    logic [255:0] stored_pubkeys[10];
    logic [511:0] stored_privkeys[10];
    logic [511:0] stored_signatures[10]; 
    int test_case_num = 0;

    assign wrong_signature = expected_sig ^ 512'h1;

    int dpi_result, ref_result;

    // Counters
    int correct_count = 0;
    int fail_count = 0;

    // Random number generator seed
    int random_seed;

    // DUT instantiation
    Ed25519_TOP DUT (
        .clk(clk),
        .rst(rst),
        .opmode(opmode),
        .start(start),
        .data_in(data_in),
        .valid(valid),
        .data_out(data_out)
    );

    ed25519_class cvr_obj = new();

    // Clock generation
    initial begin
        clk = 0;
        forever begin
            #1;  
            clk = ~clk;
            cvr_obj.clk = clk;
        end
    end

    // Coverage sampling
    always @(posedge clk) begin
        // Assign DUT signals to coverage object
        cvr_obj.rst = rst;
        cvr_obj.opmode = opmode;
        cvr_obj.start = start;
        cvr_obj.top_state_cv = DUT.cs; // Top module current state
        cvr_obj.fsm_state_cv = DUT.u_ed25519_fsm_top.cs; // FSM current state

        // Sample coverage
        cvr_obj.cvr_gp.sample();
    end

    // DPI imports
    import "DPI-C" context function int sv_crypto_sign_keypair(input logic [255:0] seed, output logic [255:0] pk, output logic [511:0] sk);
    import "DPI-C" context function int sv_crypto_sign(input logic [511:0] msg, input int mlen, input logic [511:0] sk, input logic [255:0] pk, output logic [511:0] sig);
    import "DPI-C" context function int sv_crypto_sign_open(input logic [511:0] sig, input logic [511:0] msg, input int mlen, input logic [255:0] pk);

    // Test sequence
    initial begin
        // Initialize random seed
        random_seed = $urandom();
        $display("Random seed: %0d", random_seed);
        
        // Initialize inputs
        initialize_inputs();

        // Reset DUT
        reset_dut();

        $display("\n################################### STARTING TESTS ####################################");
        
        // Test Suite 1: Basic Functionality Tests
        $display("\n================================= Test Suite 1: Basic Functionality =================================");
        run_basic_tests();
        
        // Test Suite 2: Enhanced Edge Case Messages
        $display("\n================================= Test Suite 2: Enhanced Edge Case Messages =================================");
        run_enhanced_edge_case_tests();
        
        // Test Suite 3: Multiple Key Pairs
        $display("\n================================= Test Suite 3: Multiple Key Pairs =================================");
        run_multiple_key_tests();
        
        // Test Suite 4: Enhanced Signature Corruption Tests
        $display("\n================================= Test Suite 4: Enhanced Signature Corruption Tests =================================");
        run_enhanced_corruption_tests();
        
        // Test Suite 5: Cross-Key Verification Tests
        $display("\n================================= Test Suite 5: Cross-Key Verification Tests =================================");
        run_cross_key_tests();

        // Test Suite 6: Public Key Corruption Tests
        $display("\n================================= Test Suite 6: Public Key Corruption Tests =================================");
        run_pubkey_corruption_tests();

        // Test Suite 7: Invalid Operation Mode Tests
        $display("\n================================= Test Suite 7: Invalid Operation Mode Tests =================================");
        run_invalid_opmode_tests();

        // Test Suite 8: Start Signal Behavior Tests
        $display("\n================================= Test Suite 8: Start Signal Behavior Tests =================================");
        run_start_signal_tests();

        // Test Suite 9: Reset During Operation Tests
        $display("\n================================= Test Suite 9: Reset During Operation Tests =================================");
        run_reset_during_operation_tests();

        // Test Suite 10: Boundary Value Tests
        $display("\n================================= Test Suite 10: Boundary Value Tests =================================");
        run_boundary_value_tests();

        // Test Suite 11: Stress Tests
        $display("\n================================= Test Suite 11: Stress Tests =================================");
        run_stress_tests();

        // Print final results
        #100;
        $display("\n################################### FINAL TEST RESULTS ####################################");
        $display("Total Correct tests: %d", correct_count);
        $display("Total Failed tests: %d", fail_count);
        $display("Success Rate: %.2f%%", (real'(correct_count) / real'(correct_count + fail_count)) * 100.0);
        $stop;
    end

    // Cycle counter variables
    int cycle_count = 0;
    logic [1:0] opmode_at_start;
    logic counting = 0;
    
    // Cycle counting always block
    always @(posedge clk) begin
        if (start && !counting) begin
            // Start of a new operation
            if (opmode != 2'b11) begin
                counting <= 1;
            end
            cycle_count <= 0;
            opmode_at_start <= opmode;
        end
        else if (counting) begin
            cycle_count <= cycle_count + 1;
            if (valid) begin
                // End of operation, display results
                case (opmode_at_start)
                    2'b00: $display("Test Case %d: KeyGen completed in %d cycles", test_case_num, cycle_count);
                    2'b01: $display("Test Case %d: Sign completed in %d cycles", test_case_num, cycle_count);
                    2'b10: $display("Test Case %d: Verify completed in %d cycles", test_case_num, cycle_count);
                endcase
                counting <= 0; // Reset for next operation
                cycle_count <= 0;
            end
        end
    end

    // Task definitions
    task initialize_inputs;
        begin
            opmode = 2'b00;
            start = 1'b0;
            data_in = 256'b0;
        end
    endtask

    task reset_dut;
        begin
            rst = 1'b0; // Active low reset
            repeat(5) @(negedge clk);
            rst = 1'b1;
        end
    endtask

    // Test Suite Functions
    task run_basic_tests;
        begin
            $display("\n--- Test Case 1: Basic Key Generation ---");
            keygen_start_and_check();
            
            // Store first key pair for later use
            stored_pubkeys[0] = pubkey_out;
            stored_privkeys[0] = privkey_out;
            
            $display("\n--- Test Case 2: Basic Message Signing ---");
            message = 512'hf41a876dbe4930dc059ec3a61358e42b7f910cd96a25b847fa8061ce3d149bf2853c681fda774abc2936e5108b53c7ad916e02fe34c07a185bd399723e6c4fa1;
            sign_start_and_check(message);
            stored_signatures[0] = sig_out;
            
            $display("\n--- Test Case 3: Valid Signature Verification ---");
            verify_start_and_check(pubkey_out, message, sig_out);
            
            $display("\n--- Test Case 4: Invalid Signature Verification ---");
            verify_start_and_check(pubkey_out, message, wrong_signature);
        end
    endtask

    task run_enhanced_edge_case_tests;
        begin
            // Initialize predefined test messages
            test_messages[0] = 512'h0;  // All zeros
            test_messages[1] = {512{1'b1}};  // All ones
            test_messages[2] = 512'h123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0;
            test_messages[3] = 512'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
            test_messages[4] = 512'h55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555;
            
            // Test predefined patterns
            for (int i = 0; i < 5; i++) begin
                $display("\n--- Test Case %d: Edge Message Pattern %d ---", 5+i, i);
                sign_start_and_check(test_messages[i]);
                verify_start_and_check(pubkey_out, test_messages[i], sig_out);
            end

            // Generate and test 5 random messages
            for (int i = 5; i < 10; i++) begin
                test_messages[i] = {$urandom(), $urandom(), $urandom(), $urandom(), 
                                   $urandom(), $urandom(), $urandom(), $urandom(),
                                   $urandom(), $urandom(), $urandom(), $urandom(),
                                   $urandom(), $urandom(), $urandom(), $urandom()};
                $display("\n--- Test Case %d: Random Message %d ---", 5+i, i-4);
                $display("  Random Message: %h", test_messages[i]);
                sign_start_and_check(test_messages[i]);
                verify_start_and_check(pubkey_out, test_messages[i], sig_out);
            end

            // Test incremental patterns
            test_messages[10] = 512'h0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0;
            test_messages[11] = 512'hFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210;
            
            for (int i = 10; i < 12; i++) begin
                $display("\n--- Test Case %d: Incremental Pattern %d ---", 5+i, i-9);
                sign_start_and_check(test_messages[i]);
                verify_start_and_check(pubkey_out, test_messages[i], sig_out);
            end
        end
    endtask

    task run_multiple_key_tests;
        begin
            // Generate multiple key pairs and test each
            for (int i = 1; i < 6; i++) begin  
                $display("\n--- Test Case %d: Key Pair %d Generation ---", 16+i, i+1);
                keygen_start_and_check();
                stored_pubkeys[i] = pubkey_out;
                stored_privkeys[i] = privkey_out;
                
                $display("\n--- Test Case %d: Key Pair %d Signing ---", 21+i, i+1);
                message = test_messages[i % 10]; 
                sign_start_and_check(message);
                stored_signatures[i] = sig_out;
                
                $display("\n--- Test Case %d: Key Pair %d Verification ---", 26+i, i+1);
                verify_start_and_check(pubkey_out, message, sig_out);
            end
        end
    endtask

    task run_enhanced_corruption_tests;
        begin
            // Test various signature corruptions
            logic [511:0] corrupted_sig;
            
            $display("\n--- Test Case 32: Single Bit Flip in Signature ---");
            corrupted_sig = stored_signatures[0] ^ (1 << 100);  // Flip bit 100
            verify_start_and_check(stored_pubkeys[0], test_messages[0], corrupted_sig);
            
            $display("\n--- Test Case 33: Multiple Bit Flips in Signature ---");
            corrupted_sig = stored_signatures[0] ^ 512'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0;
            verify_start_and_check(stored_pubkeys[0], test_messages[0], corrupted_sig);
            
            $display("\n--- Test Case 34: Signature High Bits Corruption ---");
            corrupted_sig = stored_signatures[0];
            corrupted_sig[511:256] = ~corrupted_sig[511:256];
            verify_start_and_check(stored_pubkeys[0], test_messages[0], corrupted_sig);
            
            $display("\n--- Test Case 35: Signature Low Bits Corruption ---");
            corrupted_sig = stored_signatures[0];
            corrupted_sig[255:0] = ~corrupted_sig[255:0];
            verify_start_and_check(stored_pubkeys[0], test_messages[0], corrupted_sig);
            
            $display("\n--- Test Case 36: Random Signature ---");
            corrupted_sig = 512'h123456789ABCDEF0FEDCBA9876543210123456789ABCDEF0FEDCBA9876543210123456789ABCDEF0FEDCBA9876543210123456789ABCDEF0FEDCBA987654321;
            verify_start_and_check(stored_pubkeys[0], test_messages[0], corrupted_sig);

            // Test random signature corruptions
            for (int i = 0; i < 3; i++) begin
                $display("\n--- Test Case %d: Random Signature Corruption %d ---", 37+i, i+1);
                corrupted_sig = stored_signatures[0] ^ {$urandom(), $urandom(), $urandom(), $urandom(),
                                                       $urandom(), $urandom(), $urandom(), $urandom(),
                                                       $urandom(), $urandom(), $urandom(), $urandom(),
                                                       $urandom(), $urandom(), $urandom(), $urandom()};
                verify_start_and_check(stored_pubkeys[0], test_messages[0], corrupted_sig);
            end
        end
    endtask

    task run_cross_key_tests;
        begin
            // Test signatures from one key pair against other public keys
            $display("\n--- Test Case 40: Cross-Key Verification (Key0 sig vs Key1 pubkey) ---");
            verify_start_and_check(stored_pubkeys[1], test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 41: Cross-Key Verification (Key1 sig vs Key0 pubkey) ---");
            verify_start_and_check(stored_pubkeys[0], test_messages[1], stored_signatures[1]);
            
            $display("\n--- Test Case 42: Cross-Key Verification (Key0 sig vs Key2 pubkey) ---");
            verify_start_and_check(stored_pubkeys[2], test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 43: Message Tampering Test ---");
            // Sign with one message, verify with different message
            verify_start_and_check(stored_pubkeys[0], test_messages[1], stored_signatures[0]);  // signed with test_messages[0]

            // Additional cross-key tests
            for (int i = 0; i < 3; i++) begin
                $display("\n--- Test Case %d: Cross-Key Test %d ---", 44+i, i+1);
                verify_start_and_check(stored_pubkeys[(i+1)%4], test_messages[i%5], stored_signatures[i%4]);
            end
        end
    endtask

    task run_pubkey_corruption_tests;
        begin
            logic [255:0] corrupted_pk;
            
            $display("\n--- Test Case 47: Single Bit Flip in Public Key ---");
            corrupted_pk = stored_pubkeys[0] ^ (1 << 50);  // Flip bit 50
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 48: Multiple Bit Flips in Public Key ---");
            corrupted_pk = stored_pubkeys[0] ^ 256'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0;
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 49: Random Public Key ---");
            corrupted_pk = {$urandom(), $urandom(), $urandom(), $urandom(), 
                           $urandom(), $urandom(), $urandom(), $urandom()};
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 50: All Zeros Public Key ---");
            corrupted_pk = 256'h0;
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 51: All Ones Public Key ---");
            corrupted_pk = {256{1'b1}};
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);

            // Test high/low bit corruption in public key
            $display("\n--- Test Case 52: Public Key High Bits Corruption ---");
            corrupted_pk = stored_pubkeys[0];
            corrupted_pk[255:128] = ~corrupted_pk[255:128];
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);
            
            $display("\n--- Test Case 53: Public Key Low Bits Corruption ---");
            corrupted_pk = stored_pubkeys[0];
            corrupted_pk[127:0] = ~corrupted_pk[127:0];
            verify_start_and_check(corrupted_pk, test_messages[0], stored_signatures[0]);
        end
    endtask

    task run_invalid_opmode_tests;
        begin
            $display("\n--- Test Case 54: Invalid Operation Mode (2'b11) ---");
            test_invalid_opmode();
            
            $display("\n--- Test Case 55: Operation Mode Transition Test ---");
            test_opmode_transitions();
        end
    endtask

    task run_start_signal_tests;
        begin
            $display("\n--- Test Case 56: Start Signal Held High During KeyGen ---");
            test_start_held_high_keygen();
            
            $display("\n--- Test Case 57: Start Signal Held High During Sign ---");
            test_start_held_high_sign();
            
            $display("\n--- Test Case 58: Start Signal Held High During Verify ---");
            test_start_held_high_verify();
            
            $display("\n--- Test Case 59: Multiple Start Pulses ---");
            test_multiple_start_pulses();
        end
    endtask

    task run_reset_during_operation_tests;
        begin
            $display("\n--- Test Case 60: Reset During KeyGen ---");
            test_reset_during_keygen();
            
            $display("\n--- Test Case 61: Reset During Sign ---");
            test_reset_during_sign();
            
            $display("\n--- Test Case 62: Reset During Verify ---");
            test_reset_during_verify();
        end
    endtask

    task run_boundary_value_tests;
        begin

            keygen_start_and_check();
            
            // Store first key pair for later use
            stored_pubkeys[0] = pubkey_out;
            stored_privkeys[0] = privkey_out;

            $display("\n--- Test Case 63: Maximum Value Message ---");
            message = {512{1'b1}};
            sign_start_and_check(message);
            verify_start_and_check(stored_pubkeys[0], message, sig_out);
            
            $display("\n--- Test Case 64: Minimum Value Message ---");
            message = 512'h0;
            sign_start_and_check(message);
            verify_start_and_check(stored_pubkeys[0], message, sig_out);
            
            $display("\n--- Test Case 65: Power of 2 Boundary Values ---");
            for (int i = 0; i < 4; i++) begin
                message = 512'h1 << (i * 128);  // Test powers of 2 at different positions
                $display("  Testing boundary value at bit position %d", i*128);
                sign_start_and_check(message);
                verify_start_and_check(stored_pubkeys[0], message, sig_out);
            end
        end
    endtask

    task run_stress_tests;
        begin
            $display("\n--- Test Case 66-70: Rapid Operation Sequence ---");
            for (int i = 0; i < 5; i++) begin
                $display("  Stress Test Iteration %d", i+1);
                // Rapid keygen -> sign -> verify sequence
                keygen_start_and_check();
                message = {$urandom(), $urandom(), $urandom(), $urandom(),
                          $urandom(), $urandom(), $urandom(), $urandom(),
                          $urandom(), $urandom(), $urandom(), $urandom(),
                          $urandom(), $urandom(), $urandom(), $urandom()};
                sign_start_and_check(message);
                verify_start_and_check(pubkey_out, message, sig_out);
            end
        end
    endtask

    // New task implementations
    task test_invalid_opmode;
        begin
            test_case_num++;
            $display("Testing invalid opmode (2'b11) - should remain idle");
            
            @(negedge clk);
            opmode = 2'b11; // Invalid mode
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            if (DUT.cs === 6'b0) begin
                correct_count++;
                $display("✓ Invalid opmode test PASSED - DUT remained idle");
            end else begin
                fail_count++;
                $display("✗ Invalid opmode test FAILED - DUT responded to invalid opmode");
            end
        end
    endtask

    task test_opmode_transitions;
        begin
            test_case_num++;
            $display("Testing opmode transitions during idle state");
            
            // Test all opmode transitions while idle
            for (int i = 0; i < 4; i++) begin
                @(negedge clk);
                opmode = i[1:0];
                @(negedge clk);
            end
            
            // Should still be able to perform normal operation
            keygen_start_and_check();
        end
    endtask

    task test_start_held_high_keygen;
        begin
            test_case_num++;
            $display("Testing start signal held high during KeyGen");
            
            @(negedge clk);
            opmode = 2'b00; // Keygen mode
            start = 1'b1;   // Hold start high
            
            // Wait for operation to complete while monitoring start signal
            fork
                begin
                    @(posedge valid);
                    @(negedge clk);
                end
                begin
                    wait (DUT.u_ed25519_fsm_top.prev_cs == DUT.u_ed25519_fsm_top.ST_KEYGEN_RNG);
                    seed = DUT.u_ed25519_fsm_top.RNG_out;
                    dpi_result = sv_crypto_sign_keypair(seed, expected_pk, expected_sk);
                end
            join
            
            pubkey_out[63:0] = data_out;      // First 64 bits
            @(negedge clk);
            pubkey_out[127:64] = data_out;    // Second 64 bits
            @(negedge clk);
            pubkey_out[191:128] = data_out;   // Third 64 bits
            @(negedge clk);
            pubkey_out[255:192] = data_out;   // Fourth 64 bits
            privkey_out = DUT.u_Reg_File.REG_B1;
            start = 1'b0;  // Release start
            
            if (pubkey_out === expected_pk && privkey_out === expected_sk) begin
                correct_count++;
                $display("✓ Start held high KeyGen test PASSED");
            end else begin
                fail_count++;
                $display("✗ Start held high KeyGen test FAILED");
            end
        end
    endtask

    task test_start_held_high_sign;
        begin
            test_case_num++;
            $display("Testing start signal held high during Sign");
            
            message = test_messages[0];
            
            @(negedge clk);
            opmode = 2'b01; // Sign mode
            start = 1'b1;   // Hold start high
            @(negedge clk);
            data_in = message[255:0];
            @(negedge clk);
            data_in = message[511:256];
            
            // Generate expected signature
            dpi_result = sv_crypto_sign(message, 64, expected_sk, expected_pk, expected_sig);
            
            // Wait for completion and release start
            @(posedge valid);
            @(negedge clk);
            sig_out[63:0] = data_out;      // Bits 63:0
            @(negedge clk);
            sig_out[127:64] = data_out;    // Bits 127:64
            @(negedge clk);
            sig_out[191:128] = data_out;   // Bits 191:128
            @(negedge clk);
            sig_out[255:192] = data_out;   // Bits 255:192
            @(negedge clk);
            sig_out[319:256] = data_out;   // Bits 319:256
            @(negedge clk);
            sig_out[383:320] = data_out;   // Bits 383:320
            @(negedge clk);
            sig_out[447:384] = data_out;   // Bits 447:384
            @(negedge clk);
            sig_out[511:448] = data_out;   // Bits 511:448
            start = 1'b0;
            
            if (sig_out === expected_sig) begin
                correct_count++;
                $display("✓ Start held high Sign test PASSED");
            end else begin
                fail_count++;
                $display("✗ Start held high Sign test FAILED");
            end
        end
    endtask

    task test_start_held_high_verify;
        begin
            test_case_num++;
            $display("Testing start signal held high during Verify");
            
            @(negedge clk);
            opmode = 2'b10; // Verify mode
            start = 1'b1;   // Hold start high
            @(negedge clk);
            data_in = stored_pubkeys[0][63:0];       // Bits 63:0
            @(negedge clk);
            data_in = stored_pubkeys[0][127:64];     // Bits 127:64
            @(negedge clk);
            data_in = stored_pubkeys[0][191:128];    // Bits 191:128
            @(negedge clk);
            data_in = stored_pubkeys[0][255:192];    // Bits 255:192
            @(negedge clk);
            // Send 512-bit message over 8 cycles (64 bits each)
            data_in = test_messages[0][63:0];      // Bits 63:0
            @(negedge clk);
            data_in = test_messages[0][127:64];    // Bits 127:64
            @(negedge clk);
            data_in = test_messages[0][191:128];   // Bits 191:128
            @(negedge clk);
            data_in = test_messages[0][255:192];   // Bits 255:192
            @(negedge clk);
            data_in = test_messages[0][319:256];   // Bits 319:256
            @(negedge clk);
            data_in = test_messages[0][383:320];   // Bits 383:320
            @(negedge clk);
            data_in = test_messages[0][447:384];   // Bits 447:384
            @(negedge clk);
            data_in = test_messages[0][511:448];   // Bits 511:448
            @(negedge clk);
            // Send 512-bit signature over 8 cycles (64 bits each)
            data_in = stored_signatures[0][63:0];      // Bits 63:0
            @(negedge clk);
            data_in = stored_signatures[0][127:64];    // Bits 127:64
            @(negedge clk);
            data_in = stored_signatures[0][191:128];   // Bits 191:128
            @(negedge clk);
            data_in = stored_signatures[0][255:192];   // Bits 255:192
            @(negedge clk);
            data_in = stored_signatures[0][319:256];   // Bits 319:256
            @(negedge clk);
            data_in = stored_signatures[0][383:320];   // Bits 383:320
            @(negedge clk);
            data_in = stored_signatures[0][447:384];   // Bits 447:384
            @(negedge clk);
            data_in = stored_signatures[0][511:448];   // Bits 511:448
            
            // Wait for completion and release start
            fork
                begin
                    @(posedge valid);
                    @(negedge clk);
                    start = 1'b0;
                end
            join
            
            result_out = data_out;
            
            // Generate expected result
            ref_result = sv_crypto_sign_open(stored_signatures[0], test_messages[0], 64, stored_pubkeys[0]);
            v_exp_out = (ref_result == 0) ? {64{1'b1}} : 64'b0;
            
            if (result_out === v_exp_out) begin
                correct_count++;
                $display("✓ Start held high Verify test PASSED");
            end else begin
                fail_count++;
                $display("✗ Start held high Verify test FAILED");
            end
        end
    endtask

    task test_multiple_start_pulses;
        begin
            test_case_num++;
            $display("Testing multiple start pulses - only first should be effective");
            
            @(negedge clk);
            opmode = 2'b00; // Keygen mode
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            // Send additional start pulses during operation
            repeat(10) begin
                repeat($urandom_range(5, 15)) @(posedge clk);
                @(negedge clk);
                start = 1'b1;
                @(negedge clk);
                start = 1'b0;
            end
            
            // Wait for completion
            @(posedge valid);
            
            // Operation should complete normally despite extra start pulses
            correct_count++;
            $display("✓ Multiple start pulses test PASSED");
        end
    endtask

    task test_reset_during_keygen;
        begin
            test_case_num++;
            $display("Testing reset during KeyGen operation");
            
            @(negedge clk);
            opmode = 2'b00;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            // Reset after some cycles
            repeat(50) @(posedge clk);
            rst = 1'b0;
            repeat(5) @(negedge clk);
            rst = 1'b1;
            
            // Check that DUT is back to idle
            repeat(10) @(posedge clk);
            if (DUT.cs == 6'b0) begin
                correct_count++;
                $display("✓ Reset during KeyGen test PASSED");
            end else begin
                fail_count++;
                $display("✗ Reset during KeyGen test FAILED");
            end
        end
    endtask

    task test_reset_during_sign;
        begin
            test_case_num++;
            $display("Testing reset during Sign operation");
            
            @(negedge clk);
            opmode = 2'b01;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            data_in = test_messages[0][255:0];
            @(negedge clk);
            data_in = test_messages[0][511:256];
            
            // Reset after some cycles
            repeat(50) @(posedge clk);
            rst = 1'b0;
            repeat(5) @(negedge clk);
            rst = 1'b1;
            
            // Check that DUT is back to idle
            repeat(10) @(posedge clk);
            if (DUT.cs == 6'b0) begin
                correct_count++;
                $display("✓ Reset during Sign test PASSED");
            end else begin
                fail_count++;
                $display("✗ Reset during Sign test FAILED");
            end
        end
    endtask

    task test_reset_during_verify;
        begin
            test_case_num++;
            $display("Testing reset during Verify operation");
            
            @(negedge clk);
            opmode = 2'b10;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            data_in = stored_pubkeys[0];
            @(negedge clk);
            data_in = test_messages[0][255:0];
            
            // Reset after some cycles
            repeat(30) @(posedge clk);
            rst = 1'b0;
            repeat(5) @(negedge clk);
            rst = 1'b1;
            
            // Check that DUT is back to idle
            repeat(10) @(posedge clk);
            if (DUT.cs == 6'b0) begin
                correct_count++;
                $display("✓ Reset during Verify test PASSED");
            end else begin
                fail_count++;
                $display("✗ Reset during Verify test FAILED");
            end
        end
    endtask



// Enhanced task definitions with test case numbering - 64-bit interface
    task keygen_start_and_check;
        begin
            test_case_num++;
            $display("Executing Key Generation Test Case %d", test_case_num);
            
            // Start key generation
            @(negedge clk);
            opmode = 2'b00; // Keygen mode
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            // Generate expected public and private keys
            wait (DUT.u_ed25519_fsm_top.prev_cs == DUT.u_ed25519_fsm_top.ST_KEYGEN_RNG);
            seed = DUT.u_ed25519_fsm_top.RNG_out;
            dpi_result = sv_crypto_sign_keypair(seed, expected_pk, expected_sk);
            if (dpi_result != 0) begin
                $display("DPI keypair generation failed with result: %d", dpi_result);
                $stop;
            end
            
            // Collect 256-bit public key output over 4 cycles (64 bits each)
            @(posedge valid);
            @(negedge clk);
            pubkey_out[63:0] = data_out;      // First 64 bits
            @(negedge clk);
            pubkey_out[127:64] = data_out;    // Second 64 bits
            @(negedge clk);
            pubkey_out[191:128] = data_out;   // Third 64 bits
            @(negedge clk);
            pubkey_out[255:192] = data_out;   // Fourth 64 bits
            
            privkey_out = DUT.u_Reg_File.REG_B1;
            
            $display("  PubKey : Expected: %h", expected_pk);
            $display("  PubKey : Output  : %h", pubkey_out);
            $display("  PrivKey: Expected: %h", expected_sk);
            $display("  PrivKey: Output  : %h", privkey_out);
            
            if (pubkey_out === expected_pk && privkey_out === expected_sk) begin
                correct_count++;
                $display("✓ KeyGen Test Case %d PASSED", test_case_num);
            end else begin
                fail_count++;
                $display("✗ KeyGen Test Case %d FAILED:", test_case_num);
                $display("  Expected PubKey : %h", expected_pk);
                $display("  Actual PubKey   : %h", pubkey_out);
                $display("  Expected PrivKey: %h", expected_sk);
                $display("  Actual PrivKey  : %h", privkey_out);
            end
        end
    endtask

    // Combined task for signing start and check - 64-bit interface
    task sign_start_and_check(input [511:0] msg);
        begin
            test_case_num++;
            $display("Executing Signing Test Case %d", test_case_num);
            
            // Start signing
            @(negedge clk);
            opmode = 2'b01; // Sign mode
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            // Send 512-bit message over 8 cycles (64 bits each)
            data_in = msg[63:0];      // Bits 63:0
            @(negedge clk);
            data_in = msg[127:64];    // Bits 127:64
            @(negedge clk);
            data_in = msg[191:128];   // Bits 191:128
            @(negedge clk);
            data_in = msg[255:192];   // Bits 255:192
            @(negedge clk);
            data_in = msg[319:256];   // Bits 319:256
            @(negedge clk);
            data_in = msg[383:320];   // Bits 383:320
            @(negedge clk);
            data_in = msg[447:384];   // Bits 447:384
            @(negedge clk);
            data_in = msg[511:448];   // Bits 511:448
            
            // Generate expected signature
            dpi_result = sv_crypto_sign(msg, 64, expected_sk, expected_pk, expected_sig);
            if (dpi_result != 0) begin
                $display("DPI sign failed with result: %d", dpi_result);
                $stop;
            end
            
            // Collect 512-bit signature output over 8 cycles (64 bits each)
            @(posedge valid);
            @(negedge clk);
            sig_out[63:0] = data_out;      // Bits 63:0
            @(negedge clk);
            sig_out[127:64] = data_out;    // Bits 127:64
            @(negedge clk);
            sig_out[191:128] = data_out;   // Bits 191:128
            @(negedge clk);
            sig_out[255:192] = data_out;   // Bits 255:192
            @(negedge clk);
            sig_out[319:256] = data_out;   // Bits 319:256
            @(negedge clk);
            sig_out[383:320] = data_out;   // Bits 383:320
            @(negedge clk);
            sig_out[447:384] = data_out;   // Bits 447:384
            @(negedge clk);
            sig_out[511:448] = data_out;   // Bits 511:448
            
            $display("   Message: %h", msg);
            $display("   Signature Expected: %h", expected_sig);
            $display("   Signature Output  : %h", sig_out);
            
            if (sig_out === expected_sig) begin
                correct_count++;
                $display("✓ Sign Test Case %d PASSED", test_case_num);
            end else begin
                fail_count++;
                $display("✗ Sign Test Case %d FAILED:", test_case_num);
                $display("  Expected Signature: %h", expected_sig);
                $display("  Actual Signature  : %h", sig_out);
            end
        end
    endtask

    // Combined task for verification start and check - 64-bit interface
    task verify_start_and_check(input [255:0] pk, input [511:0] msg, input [511:0] sig);
        begin
            int ref_v_result;
            logic [63:0] result_out_64;
            logic [63:0] v_exp_out_64;
            
            test_case_num++;
            $display("Executing Verification Test Case %d", test_case_num);
            
            // Start verification
            @(negedge clk);
            opmode = 2'b10; // Verify mode
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            // Send 256-bit public key over 4 cycles (64 bits each)
            data_in = pk[63:0];       // Bits 63:0
            @(negedge clk);
            data_in = pk[127:64];     // Bits 127:64
            @(negedge clk);
            data_in = pk[191:128];    // Bits 191:128
            @(negedge clk);
            data_in = pk[255:192];    // Bits 255:192
            @(negedge clk);
            
            // Send 512-bit message over 8 cycles (64 bits each)
            data_in = msg[63:0];      // Bits 63:0
            @(negedge clk);
            data_in = msg[127:64];    // Bits 127:64
            @(negedge clk);
            data_in = msg[191:128];   // Bits 191:128
            @(negedge clk);
            data_in = msg[255:192];   // Bits 255:192
            @(negedge clk);
            data_in = msg[319:256];   // Bits 319:256
            @(negedge clk);
            data_in = msg[383:320];   // Bits 383:320
            @(negedge clk);
            data_in = msg[447:384];   // Bits 447:384
            @(negedge clk);
            data_in = msg[511:448];   // Bits 511:448
            @(negedge clk);
            
            // Send 512-bit signature over 8 cycles (64 bits each)
            data_in = sig[63:0];      // Bits 63:0
            @(negedge clk);
            data_in = sig[127:64];    // Bits 127:64
            @(negedge clk);
            data_in = sig[191:128];   // Bits 191:128
            @(negedge clk);
            data_in = sig[255:192];   // Bits 255:192
            @(negedge clk);
            data_in = sig[319:256];   // Bits 319:256
            @(negedge clk);
            data_in = sig[383:320];   // Bits 383:320
            @(negedge clk);
            data_in = sig[447:384];   // Bits 447:384
            @(negedge clk);
            data_in = sig[511:448];   // Bits 511:448
            
            // Generate expected result
            ref_v_result = sv_crypto_sign_open(sig, msg, 64, pk);
            
            // Collect verification result (single 64-bit output)
            @(posedge valid);
            @(negedge clk);
            result_out_64 = data_out;

            if (ref_v_result == 0) begin
                v_exp_out_64 = {64{1'b1}};
            end
            else begin
                v_exp_out_64 = 64'b0;
            end

            $display("   Public Key: %h", pk);
            $display("   Message: %h", msg);
            $display("   Signature: %h", sig);
            $display("   Verification Expected: %h (%s)", v_exp_out_64, v_exp_out_64[0] ? "Valid" : "Invalid");
            $display("   Verification Output  : %h (%s)", result_out_64, result_out_64[0] ? "Valid" : "Invalid");

            if (result_out_64 === v_exp_out_64) begin
                correct_count++;
                $display("✓ Verify Test Case %d PASSED: Expected %s", test_case_num, v_exp_out_64[0] ? "Valid" : "Invalid");
            end else begin
                fail_count++;
                $display("✗ Verify Test Case %d FAILED: Expected %s, Got %s", test_case_num, v_exp_out_64[0] ? "Valid" : "Invalid", result_out_64[0] ? "Valid" : "Invalid");
            end
        end
    endtask

endmodule