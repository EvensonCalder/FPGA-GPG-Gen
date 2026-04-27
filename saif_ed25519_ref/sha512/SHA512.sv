module SHA512 (
    input         clk,
    input         rst,
    input         start_sha512,
    input  [1:0]  mode,         // 2'b00:32 bytes, 2'b01:96 bytes, default:128 bytes
    input  [1023:0] message,    // message input (128 bytes);
    output reg    end_sha512,   // high when hash is ready
    output reg [511:0] hash     // final 512-bit digest
);

typedef enum reg [2:0] {
		IDLE            = 3'b000,
		COMPRESS1_START = 3'b001,
		COMPRESS1       = 3'b011,
		COMPRESS2_START = 3'b010,
		COMPRESS2       = 3'b110,
		FINALIZE        = 3'b111
} states_e;

states_e cs, ns;

// H Main register and H updated after compressing
reg  [511:0] H;
wire [511:0] H_updated;
// padded 1024-bit locks
wire [1023:0] padded_block1, padded_block2;
wire block2_valid;
// input block to compress module (block2 if state is COMPRESS2_START or COMPRESS2 , otherwise block1)
wire  [1023:0] block_processed;
// control signals of processing module 
reg start_compressing;
wire compress_end;

// Padding module (combinational)
SHA512_PADDING Padding (
	.message     (message),
	.mode        (mode),
	.block1      (padded_block1),
	.block2      (padded_block2),
	.block2_valid(block2_valid)
	);

// Main compression module
SHA512_Compress Compress (
	.rst         (rst),
	.clk         (clk),
	.start       (start_compressing),
	.block       (block_processed),
	.H_in        (H),
	.compress_end(compress_end),
	.H_out       (H_updated)
);

// assigning input block to compressing module based on the currrent state 
assign block_processed = ( (cs==COMPRESS2_START) || (cs ==COMPRESS2) )? padded_block2 : padded_block1;

always_ff @(posedge clk or negedge rst) begin
	if(~rst) begin
		cs <= IDLE;
	end else begin
		cs <= ns;
	end
end

// Next state logic
always @(*) begin
	case (cs)
		IDLE : begin
			if (start_sha512) begin
				ns = COMPRESS1_START;
			end
			else begin
				ns = IDLE;
			end
		end
		COMPRESS1_START : begin
			ns = COMPRESS1;
		end
		COMPRESS1 : begin
			if (compress_end) begin
				if (block2_valid) begin      // If the input is 128-Byte we will process the second block otherwise we finalize the hash
					ns = COMPRESS2_START;
				end
				else begin
					ns = FINALIZE;
				end
			end
			else begin
				ns = COMPRESS1;
			end
		end
		COMPRESS2_START : begin
			ns = COMPRESS2;
		end
		COMPRESS2 : begin
			if (compress_end) begin
				ns = FINALIZE;
			end
			else begin
				ns = COMPRESS2;
			end
		end
		FINALIZE : begin
			ns = IDLE;
		end
		default : ns = IDLE;
	endcase
end

// Ouput and control signals logic
always_ff @(posedge clk or negedge rst) begin
	if(~rst) begin
		// Initial H values
		H[511:448]        <= 64'h6a09e667f3bcc908;
        H[447:384]        <= 64'hbb67ae8584caa73b;
        H[383:320]        <= 64'h3c6ef372fe94f82b;
        H[319:256]        <= 64'ha54ff53a5f1d36f1;
        H[255:192]        <= 64'h510e527fade682d1;
        H[191:128]        <= 64'h9b05688c2b3e6c1f;
        H[127:64]         <= 64'h1f83d9abfb41bd6b;
        H[63:0]           <= 64'h5be0cd19137e2179;
        
        // Reset compressing control signal
        start_compressing <= 1'b0;

        // Reset ouputs
        end_sha512        <= 1'b0;
        hash              <= 512'b0;
	end 
	else begin
		case (cs)
			IDLE : begin
				H[511:448]        <= 64'h6a09e667f3bcc908;
    		    H[447:384]        <= 64'hbb67ae8584caa73b;
    		    H[383:320]        <= 64'h3c6ef372fe94f82b;
    		    H[319:256]        <= 64'ha54ff53a5f1d36f1;
    		    H[255:192]        <= 64'h510e527fade682d1;
    		    H[191:128]        <= 64'h9b05688c2b3e6c1f;
    		    H[127:64]         <= 64'h1f83d9abfb41bd6b;
    		    H[63:0]           <= 64'h5be0cd19137e2179;
        
    		    start_compressing <= 1'b0;

    		    end_sha512        <= 1'b0;
			end
			COMPRESS1_START : begin
				start_compressing <= 1'b1;
			end
			COMPRESS1 : begin
				start_compressing <= 1'b0;

				// Update H when compression ends
				if (compress_end) begin
					H             <= H_updated;
				end
			end
			COMPRESS2_START : begin
				start_compressing <= 1'b1;
			end
			COMPRESS2 : begin
				start_compressing <= 1'b0;

				// Update H when compression ends
				if (compress_end) begin
					H             <= H_updated;
				end
			end
			FINALIZE : begin
				end_sha512        <= 1'b1;
    		    hash              <= H;
			end
			default : begin
				H[511:448]        <= 64'h6a09e667f3bcc908;
    		    H[447:384]        <= 64'hbb67ae8584caa73b;
    		    H[383:320]        <= 64'h3c6ef372fe94f82b;
    		    H[319:256]        <= 64'ha54ff53a5f1d36f1;
    		    H[255:192]        <= 64'h510e527fade682d1;
    		    H[191:128]        <= 64'h9b05688c2b3e6c1f;
    		    H[127:64]         <= 64'h1f83d9abfb41bd6b;
    		    H[63:0]           <= 64'h5be0cd19137e2179;
        
    		    start_compressing <= 1'b0;

    		    end_sha512        <= 1'b0;
    		    hash              <= H;
			end
		endcase
	end
end

endmodule