module SHA512_wrapper_mux (
    input         clk,
    input         rst,
    input         start_sha512,
    input  [1:0]  sha512_mode,       // selects Mux mode *and* is passed to the SHA core
    input  [511:0] hash_message_in,  // 64 B message
    input  [255:0] random_number,    // 32 B random number
    input  [255:0] hash_pubkey_in,   // 32 B public key
    input  [255:0] R,                // 32 B signature component R
    input  [255:0] seckey32_in,      // 32 B secret key
    output        end_sha512,        // high when hash is ready
    output [511:0] hash              // final 512-bit digest (byte-reversed)
);

    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //  Build the 128 B SHA input by selecting mode and byte-reversing
    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

    reg [1023:0] sha_input;
    always @* begin
        case (sha512_mode)
            // Mode 0: Key generation
            2'b00:  sha_input = { 768'b0, rev32(random_number)};

            // Mode 1: Signature nonce generation
            2'b01:  sha_input = { 256'b0,  rev32(seckey32_in),  rev64(hash_message_in)  };

            // Mode 2: HRAM generation (and default)
            default: sha_input = { rev32(R),  rev32(hash_pubkey_in),   rev64(hash_message_in)  };
        endcase
    end

    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //  Instantiate your SHA-512 core
    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

    wire        core_end;
    wire [511:0] core_hash;

    SHA512 u_sha512 (
        .clk(clk),
        .rst(rst),
        .start_sha512(start_sha512),
        .mode(sha512_mode),
        .message(sha_input),
        .end_sha512(core_end),
        .hash(core_hash)
    );

    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //  Wrap up: reverse the full 64 B output
    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

    assign end_sha512 = core_end;
    assign hash       = rev64(core_hash);


    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //  byte-reverse functions (for handling big-endian , little-endian communication)
    //––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

    function automatic [255:0] rev32;
        input [255:0] d;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1)
                rev32[i*8 +: 8] = d[(31-i)*8 +: 8];
        end
    endfunction

    function automatic [511:0] rev64;
        input [511:0] d;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                rev64[i*8 +: 8] = d[(63-i)*8 +: 8];
        end
    endfunction

endmodule
