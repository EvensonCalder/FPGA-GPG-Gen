module SHA512_Compress (
		input	clk,
		input	rst,
		input	start,
		input   [1023:0] block,	 	// 1024-bit message block
		input   [511:0]	H_in,		// current H value
		output  reg	compress_end,
		output  reg [511:0] H_out
);

typedef enum reg [2:0] {
		IDLE				= 3'b000,
		PREPARE_1			= 3'b001,
		PREPARE_2			= 3'b011,
		COMPRESS_CALC		= 3'b010,
		COMPRESS_UPDATE		= 3'b100,
		UPDATE_H			= 3'b110
		
} states_e;

states_e cs, ns;

// Working variables for compression
reg [63:0] a, b, c, d, e, f, g, h;

// T1, T2 compression variables
wire [63:0] T1;
wire [63:0] T2;
reg  [63:0] T1_q;
reg  [63:0] T2_q;

// W array (80 words) which takes values in prepare states and used in compress state
reg [63:0] W [0:79];

reg [6:0] prepare_counter;		// counter for prepare state
reg [6:0] comp_round;			// round counter from 0 to 79 (also used as address for K ROM)
wire [63:0] K_i;						// K output used in the compression loop


// SHA-512 K constants ROM
SHA512_K_ROM K_ROM (
	.addr (comp_round),
	.K_out(K_i)
);

// SHA-512 functions
function [63:0] rotr;
	input [63:0] x;
	input [5:0] n;
	begin
		rotr = (x >> n) | (x << (64 - n));
	end
endfunction

function [63:0] Sigma0;
	input [63:0] x;
	begin
		Sigma0 = rotr(x, 28) ^ rotr(x, 34) ^ rotr(x, 39);
	end
endfunction

function [63:0] Sigma1;
	input [63:0] x;
	begin
		Sigma1 = rotr(x, 14) ^ rotr(x, 18) ^ rotr(x, 41);
	end
endfunction

function [63:0] sigma0;
	input [63:0] x;
	begin
		sigma0 = rotr(x, 1) ^ rotr(x, 8) ^ (x >> 7);
	end
endfunction

function [63:0] sigma1;
	input [63:0] x;
	begin
		sigma1 = rotr(x, 19) ^ rotr(x, 61) ^ (x >> 6);
	end
endfunction

function [63:0] Ch;
	input [63:0] x, y, z;
	begin
		Ch = (x & y) ^ (~x & z);
	end
endfunction

function [63:0] Maj;
	input [63:0] x, y, z;
	begin
		Maj = (x & y) ^ (x & z) ^ (y & z);
	end
endfunction


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
			if (start) begin
				ns = PREPARE_1;
			end
			else begin
				ns = IDLE;
			end
		end
		PREPARE_1 : begin
			ns = PREPARE_2;
		end
		PREPARE_2 : begin
			if (prepare_counter == 7'd79) begin
				ns = COMPRESS_CALC;
			end
			else begin
				ns = PREPARE_2;
			end
		end
		COMPRESS_CALC : begin
			ns = COMPRESS_UPDATE;
		end
		COMPRESS_UPDATE : begin
			if (comp_round == 7'd79) begin
				ns = UPDATE_H;
			end
			else begin
				ns = COMPRESS_CALC;
			end
		end
		UPDATE_H : begin
			ns = IDLE;
		end
		default : ns = IDLE;
	endcase
end



// Combinational assignment for T1 and T2
assign T1 = h + Sigma1(e) + Ch(e, f, g) + K_i + W[comp_round];
assign T2 = Sigma0(a) + Maj(a, b, c);

// compressing logic
always_ff @(posedge clk or negedge rst) begin
	if(~rst) begin
		// Reset working variables
		a <= 64'b0; b <= 64'b0; c <= 64'b0; d <= 64'b0; e <= 64'b0; f <= 64'b0; g <= 64'b0; h <= 64'b0; 
		// Reset counters
		prepare_counter <= 7'b0; comp_round <= 7'b0;
		T1_q <= 64'b0;
		T2_q <= 64'b0;

		for (int i = 0; i < 80; i++) begin
			W[i] <= 64'b0;
		end

		// Reset outputs
		compress_end <= 1'b0;
		H_out        <= 512'b0;
	end 
	else begin
		case (cs)
			IDLE : begin
				compress_end <= 1'b0;
				prepare_counter <= 7'b0; comp_round <= 7'b0;
			end
			PREPARE_1 : begin
				// inititalizing working variables
				a <= H_in[511:448];
				b <= H_in[447:384];
				c <= H_in[383:320];
				d <= H_in[319:256];
				e <= H_in[255:192];
				f <= H_in[191:128];
				g <= H_in[127:64];
				h <= H_in[63:0];

				// Preparing first 16 words of W
				W[0]  <= block[1023:960];
				W[1]  <= block[959:896];
				W[2]  <= block[895:832];
				W[3]  <= block[831:768];
				W[4]  <= block[767:704];
				W[5]  <= block[703:640];
				W[6]  <= block[639:576];
				W[7]  <= block[575:512];
				W[8]  <= block[511:448];
				W[9]  <= block[447:384];
				W[10] <= block[383:320];
				W[11] <= block[319:256];
				W[12] <= block[255:192];
				W[13] <= block[191:128];
				W[14] <= block[127:64];
				W[15] <= block[63:0];

               	// update counter
				prepare_counter <= 7'd16;
			end
			PREPARE_2 : begin
			    if (prepare_counter != 7'd80) begin
                    W[prepare_counter] <= sigma1(W[prepare_counter-2]) + W[prepare_counter-7] + sigma0(W[prepare_counter-15]) + W[prepare_counter-16];

               		// update counter
                    prepare_counter <= prepare_counter + 1;
                end 
			end
			COMPRESS_CALC : begin
				if (comp_round != 80) begin
					T1_q <= T1;
					T2_q <= T2;
				end
			end
			COMPRESS_UPDATE : begin
				if (comp_round != 80) begin
					a <= T1_q + T2_q;
              		b <= a;
               		c <= b;
               		d <= c;
					e <= d + T1_q;
               		f <= e;
               		g <= f;
               		h <= g;

               		// update counter
               		comp_round <= comp_round + 1;
				end
			end
			UPDATE_H : begin
				H_out[511:448] <= H_in[511:448] + a;
            	H_out[447:384] <= H_in[447:384] + b;
            	H_out[383:320] <= H_in[383:320] + c;
            	H_out[319:256] <= H_in[319:256] + d;
            	H_out[255:192] <= H_in[255:192] + e;
            	H_out[191:128] <= H_in[191:128] + f;
            	H_out[127:64]  <= H_in[127:64]  + g;
            	H_out[63:0]    <= H_in[63:0]    + h;
            	compress_end   <= 1'b1;
			end
			default : begin
				compress_end <= 1'b0;
				prepare_counter <= 7'b0; comp_round <= 7'b0;
			end
		endcase
	end
end

endmodule
