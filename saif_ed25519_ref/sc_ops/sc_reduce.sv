module sc_reduce (
    input                     clk,
    input                     rst,
    input                     start,
    input       [511:0]        data_in,  // 64-byte input
    output reg  [255:0]       data_out, // 32-byte output
    output reg                done
);

typedef enum logic [1:0] {
    IDLE  =2'b00,
    LOAD  =2'b01,
    PROCESS =2'b10,
    FINISH =2'b11
} state_e;


state_e cs, ns;
reg [6:0] cycle_counter;

// The mask value (2^21 - 1)
localparam logic [63:0] MASK21 = 64'd2097151;

// Intermediate values
reg signed [63:0] s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, s23;
reg signed [63:0] carry0, carry1, carry2, carry3, carry4, carry5, carry6, carry7, carry8, carry9, carry10, carry11, carry12, carry13,
 carry14,carry15, carry16;
reg done_process;

// Fixed SHL64 function - matches C macro behavior
function signed [63:0] SHL64;
  input signed [63:0] s;
  input [5:0] lshift; 
  begin
    SHL64 = signed'(unsigned'(s) << lshift);
  end
endfunction



function  [63:0] load_3;
    input integer offset;         
    input logic [511:0] data_in;     
    begin
      load_3 = {40'd0,
                         data_in[8*(offset+2)+7 -: 8],   // s[offset+2] -> [23:16]
                         data_in[8*(offset+1)+7 -: 8],   // s[offset+1] -> [15:8]
                         data_in[8*offset+7 -: 8]};      // s[offset]   -> [7:0]
    end
  endfunction

 
  function  [63:0] load_4;
    input integer offset;         
    input logic [511:0] data_in;     
    begin
      load_4 = {32'd0,
                         data_in[8*(offset+3)+7 -: 8],   // s[offset+3] -> [31:24]
                         data_in[8*(offset+2)+7 -: 8],   // s[offset+2] -> [23:16]
                         data_in[8*(offset+1)+7 -: 8],   // s[offset+1] -> [15:8]
                         data_in[8*offset+7 -: 8]};      // s[offset]   -> [7:0]
    end
  endfunction

 always @(posedge clk or negedge rst)
 begin
  if(!rst)
   begin
     cs <=IDLE ;
   end
  else
   begin
     cs <=ns ;
   end
 end

always @(*) begin
    case (cs)
        IDLE: begin
            if (start) begin
                ns =LOAD;
            end 
            else begin
                ns =IDLE;   
            end 
        end
        
        LOAD: begin
            ns =PROCESS;
        end

        PROCESS: begin
            if (done_process) begin
              ns =FINISH;  
            end 
            else begin
              ns =PROCESS;  
            end 
        end

        FINISH: begin
            ns =IDLE;
        end

        default: ns =IDLE;
    endcase
end


   // Output Logic
always @(posedge clk or negedge rst) begin
     if(!rst)
       begin
        data_out <=0;

        cycle_counter <=0;
        done <=0;
        done_process <=0;

        s0 <=0; s1 <=0; s2 <=0; s3 <=0; s4 <=0; s5 <=0; s6 <=0; s7 <=0;
        s8 <=0; s9 <=0; s10 <=0; s11 <=0; s12 <=0; s13 <=0; s14 <=0;
        s15 <=0; s16 <=0; s17 <=0; s18 <=0; s19 <=0; s20 <=0; s21 <=0;
        s22 <=0; s23 <=0;

        carry0 <=0; carry1 <=0; carry2 <=0; carry3 <=0; carry4 <=0; carry5 <=0; carry6 <=0; 
        carry7 <=0; carry8 <=0; carry9 <=0; carry10 <=0; carry11 <=0; carry12 <=0; carry13 <=0;
         carry14 <=0;carry15 <=0; carry16 <=0;
   end
        
   else begin
       
   
    case (cs)
        IDLE : begin
          done <=0;
          done_process <=0;
          cycle_counter <=0;
        end

        LOAD : begin

        s0  <=load_3(0, data_in)                  & MASK21;
        s1  <=(load_4(2, data_in)  >> 5)          & MASK21;
        s2  <=(load_3(5, data_in)  >> 2)          & MASK21;
        s3  <=(load_4(7, data_in)  >> 7)          & MASK21;
        s4<= (load_4(10, data_in) >> 4)           & MASK21;
        s5  <=(load_3(13, data_in) >> 1)          & MASK21;
        s6<= (load_4(15, data_in) >> 6)           & MASK21;
        s7<= (load_3(18, data_in) >> 3)           & MASK21;
        s8<= load_3(21, data_in)                  & MASK21;
        s9  <=(load_4(23, data_in) >> 5)          & MASK21;
        s10<= (load_3(26, data_in) >> 2)          & MASK21;
        s11 <=(load_4(28, data_in) >> 7)          & MASK21;
        s12<= (load_4(31, data_in) >> 4)          & MASK21;
        s13 <=(load_3(34, data_in) >> 1)          & MASK21;
        s14<= (load_4(36, data_in) >> 6)          & MASK21;
        s15<= (load_3(39, data_in) >> 3)          & MASK21;
        s16<= load_3(42, data_in)                 & MASK21;
        s17<= (load_4(44, data_in) >> 5)          & MASK21;
        s18 <=(load_3(47, data_in) >> 2)          & MASK21;
        s19 <=(load_4(49, data_in) >> 7)          & MASK21;
        s20<= (load_4(52, data_in) >> 4)          & MASK21;
        s21 <=(load_3(55, data_in) >> 1)          & MASK21;
        s22<= (load_4(57, data_in) >> 6)          & MASK21;
        s23 <=load_4(60, data_in) >> 3;  // Note: s23 is not masked
        end
        PROCESS : begin
             case(cycle_counter)
                    0: begin
                          s11 <=s11 + (s23 * 64'sd666643);
                          s12 <=s12 + (s23 * 64'sd470296);
                          s13 <=s13 + (s23 * 64'sd654183);
                          s14 <=s14 - (s23 * 64'sd997805);
                          s15 <=s15 + (s23 * 64'sd136657);
                          s16 <=s16 - (s23 * 64'sd683901);
                          s23 <=0;
                    end
                    1: begin
                          s10 <=s10 + (s22 * 64'sd666643);
                          s11 <=s11 + (s22 * 64'sd470296);
                          s12 <=s12 + (s22 * 64'sd654183);
                          s13 <=s13 - (s22 * 64'sd997805);
                          s14 <=s14 + (s22 * 64'sd136657);
                          s15 <=s15 - (s22 * 64'sd683901);
                          s22 <=0;
                    end
                    2: begin
                          s9  <=s9  + (s21 * 64'sd666643);
                          s10 <=s10 + (s21 * 64'sd470296);
                          s11 <=s11 + (s21 * 64'sd654183);
                          s12 <=s12 - (s21 * 64'sd997805);
                          s13 <=s13 + (s21 * 64'sd136657);
                          s14 <=s14 - (s21 * 64'sd683901);
                          s21 <=0;
                    end      
                    3: begin
                         s8  <=s8  + (s20 * 64'sd666643);
                         s9  <=s9  + (s20 * 64'sd470296);
                         s10 <=s10 + (s20 * 64'sd654183);
                         s11 <=s11 - (s20 * 64'sd997805);
                         s12 <=s12 + (s20 * 64'sd136657);
                         s13 <=s13 - (s20 * 64'sd683901);
                         s20 <=0; 
                    end      
                    4: begin
                         s7  <=s7  + (s19 * 64'sd666643);
                         s8  <=s8  + (s19 * 64'sd470296);
                         s9  <=s9  + (s19 * 64'sd654183);
                         s10 <=s10 - (s19 * 64'sd997805);
                         s11 <=s11 + (s19 * 64'sd136657);
                         s12 <=s12 - (s19 * 64'sd683901);
                         s19 <=0;    
                    end     
                    5: begin
                         s6  <=s6  + (s18 * 64'sd666643);
                         s7  <=s7  + (s18 * 64'sd470296);
                         s8  <=s8  + (s18 * 64'sd654183);
                         s9  <=s9  - (s18 * 64'sd997805);
                         s10 <=s10 + (s18 * 64'sd136657);
                         s11 <=s11 - (s18 * 64'sd683901);
                         s18 <=0;   
                    end      
                    6: begin
                         carry6  <=(s6  + (1<<20)) >>> 21; 
                         carry8  <=(s8  + (1<<20)) >>> 21; 
                         carry10 <=(s10 + (1<<20)) >>> 21; 
                         carry12 <=(s12 + (1<<20)) >>> 21; 
                         carry14 <=(s14 + (1<<20)) >>> 21; 
                         carry16 <=(s16 + (1<<20)) >>> 21; 
                    end     
                    7: begin
                          s7  <=s7 + carry6;     s6 <=s6  - SHL64(carry6,21);
                          s9  <=s9 + carry8;     s8 <=s8  - SHL64(carry8,21);
                          s11  <=s11 + carry10; s10 <=s10 - SHL64(carry10,21);
                          s13  <=s13 + carry12; s12 <=s12 - SHL64(carry12,21);
                          s15  <=s15 + carry14; s14 <=s14 - SHL64(carry14,21);
                          s17  <=s17 + carry16; s16 <=s16 - SHL64(carry16,21);
                    end      
                    8: begin
                         carry7  <=(s7  + (1<<20)) >>> 21; 
                         carry9  <=(s9  + (1<<20)) >>> 21; 
                         carry11 <=(s11 + (1<<20)) >>> 21; 
                         carry13 <=(s13 + (1<<20)) >>> 21; 
                         carry15 <=(s15 + (1<<20)) >>> 21; 
                    end     
                    9: begin
                          s8   <=s8  + carry7;  s7  <=s7  - SHL64(carry7,21);
                          s10  <=s10 + carry9;  s9  <=s9  - SHL64(carry9,21);
                          s12  <=s12 + carry11; s11 <=s11 - SHL64(carry11,21);
                          s14  <=s14 + carry13; s13 <=s13 - SHL64(carry13,21);
                          s16  <=s16 + carry15; s15 <=s15 - SHL64(carry15,21);
                    end      
                    10: begin
                          s5 <=s5 + (s17 * 64'sd666643);
                          s6 <=s6 + (s17 * 64'sd470296);
                          s7 <=s7 + (s17 * 64'sd654183);
                          s8 <=s8 - (s17 * 64'sd997805);
                          s9 <=s9 + (s17 * 64'sd136657);
                          s10 <=s10 - (s17 * 64'sd683901);
                          s17 <=0;
                    end
                    11: begin
                          s4 <=s4 + (s16 * 64'sd666643);
                          s5 <=s5 + (s16 * 64'sd470296);
                          s6 <=s6 + (s16 * 64'sd654183);
                          s7 <=s7 - (s16 * 64'sd997805);
                          s8 <=s8 + (s16 * 64'sd136657);
                          s9 <=s9 - (s16 * 64'sd683901);
                          s16 <=0;
                    end
                    12: begin
                          s3 <=s3 + (s15 * 64'sd666643);
                          s4 <=s4 + (s15 * 64'sd470296);
                          s5 <=s5 + (s15 * 64'sd654183);
                          s6 <=s6 - (s15 * 64'sd997805);
                          s7 <=s7 + (s15 * 64'sd136657);
                          s8 <=s8 - (s15 * 64'sd683901);
                          s15 <=0;
                    end
                    13: begin
                          s2 <=s2 + (s14 * 64'sd666643);
                          s3 <=s3 + (s14 * 64'sd470296);
                          s4 <=s4 + (s14 * 64'sd654183);
                          s5 <=s5 - (s14 * 64'sd997805);
                          s6 <=s6 + (s14 * 64'sd136657);
                          s7 <=s7 - (s14 * 64'sd683901);
                          s14 <=0;
                    end
                    14: begin
                          s1 <=s1 + (s13 * 64'sd666643);
                          s2 <=s2 + (s13 * 64'sd470296);
                          s3 <=s3 + (s13 * 64'sd654183);
                          s4 <=s4 - (s13 * 64'sd997805);
                          s5 <=s5 + (s13 * 64'sd136657);
                          s6 <=s6 - (s13 * 64'sd683901);
                          s13 <=0;
                    end
                    15: begin
                          s0 <=s0 + (s12 * 64'sd666643);
                          s1 <=s1 + (s12 * 64'sd470296);
                          s2 <=s2 + (s12 * 64'sd654183);
                          s3 <=s3 - (s12 * 64'sd997805);
                          s4 <=s4 + (s12 * 64'sd136657);
                          s5 <=s5 - (s12 * 64'sd683901);
                          s12 <=0;
                    end
                     16: begin
                         carry0 <=(s0 + (1<<20)) >>>21; 
                         carry2 <=(s2 + (1<<20)) >>> 21; 
                         carry4 <=(s4 + (1<<20)) >>> 21; 
                         carry6 <=(s6 + (1<<20)) >>> 21; 
                         carry8 <=(s8 + (1<<20)) >>> 21; 
                         carry10 <=(s10 + (1<<20)) >>> 21; 
                    end     
                    17: begin
                          s1  <=s1 + carry0; s0 <=s0 - SHL64(carry0,21);
                          s3  <=s3 + carry2; s2 <=s2 - SHL64(carry2,21);
                          s5  <=s5 + carry4; s4 <=s4 - SHL64(carry4,21);
                          s7  <=s7 + carry6; s6 <=s6 -  SHL64(carry6,21);
                          s9  <=s9 + carry8; s8 <=s8 - SHL64(carry8,21);
                          s11  <=s11 + carry10; s10 <=s10 - SHL64(carry10,21);
                    end      
                    18: begin
                         carry1 <=(s1 + (1<<20)) >>> 21; 
                         carry3 <=(s3 + (1<<20)) >>> 21; 
                         carry5 <=(s5 + (1<<20)) >>>21; 
                         carry7 <=(s7 + (1<<20)) >>> 21; 
                         carry9 <=(s9 + (1<<20)) >>> 21; 
                         carry11 <=(s11 + (1<<20)) >>> 21; 
                    end     
                    19: begin
                          s2  <=s2 + carry1; s1 <=s1 - SHL64(carry1,21);
                          s4  <=s4 + carry3; s3 <=s3 - SHL64(carry3,21);
                          s6  <=s6 + carry5; s5 <=s5 - SHL64(carry5,21);
                          s8  <=s8 + carry7; s7 <=s7 -  SHL64(carry7,21);
                          s10  <=s10 + carry9; s9 <=s9 - SHL64(carry9,21);
                          s12  <=s12 + carry11; s11 <=s11 - SHL64(carry11,21);
                    end    
                    20: begin
                          s0 <=s0 + (s12 * 666643);
                          s1 <=s1 + (s12 * 470296);
                          s2 <=s2 + (s12 * 654183);
                          s3 <=s3 - (s12 * 997805);
                          s4 <=s4 + (s12 * 136657);
                          s5 <=s5 - (s12 * 683901);
                          s12 <=0;
                    end  
                    // First carry propagation sequence (PROCESS STAGE 21, 22, 23)
                    21: begin
                         carry0 <=s0 >>> 21; 
                    end     
                    22: begin
                         s1  <=s1 + carry0; 
                         s0 <=s0 - SHL64(carry0,21);
                    end      
                    23: begin
                         carry1 <=s1  >>> 21;  // Use updated s1 value
                    end
                    24: begin
                         s2  <=s2 + carry1; 
                         s1 <=s1 - SHL64(carry1,21);
                    end
                    25: begin
                         carry2 <= s2 >>> 21;  // Use updated s2 value
                    end
                    26: begin
                         s3  <=s3 + carry2; 
                         s2 <=s2 - SHL64(carry2,21);
                    end
                    27: begin
                         carry3 <= s3   >>> 21;  // Use updated s3 value
                    end
                    28: begin
                         s4  <=s4 + carry3; 
                         s3 <=s3 - SHL64(carry3,21);
                    end
                    29: begin
                         carry4 <= s4  >>> 21;  // Use updated s4 value
                    end
                    30: begin
                         s5  <=s5 + carry4; 
                         s4 <=s4 - SHL64(carry4,21);
                    end
                    31: begin
                         carry5 <= s5  >>> 21;  // Use updated s5 value
                    end
                    32: begin
                         s6  <=s6 + carry5; 
                         s5 <=s5 - SHL64(carry5,21);
                    end
                    33: begin
                         carry6 <=s6  >>> 21;  // Use updated s6 value
                    end
                    34: begin
                         s7  <=s7 + carry6; 
                         s6 <=s6 - SHL64(carry6,21);
                    end
                    35: begin
                         carry7 <=s7  >>> 21;  // Use updated s7 value
                    end
                    36: begin
                         s8  <=s8 + carry7; 
                         s7 <=s7 - SHL64(carry7,21);
                    end
                    37: begin
                         carry8 <=s8 >>> 21;  // Use updated s8 value
                    end
                    38: begin
                         s9  <=s9 + carry8; 
                         s8 <=s8 - SHL64(carry8,21);
                    end
                    39: begin
                         carry9 <=s9 >>> 21;  // Use updated s9 value
                    end
                    40: begin
                         s10  <=s10 + carry9; 
                         s9 <=s9 - SHL64(carry9,21);
                    end
                    41: begin
                         carry10 <=s10  >>> 21;  // Use updated s10 value
                    end
                    42: begin
                         s11  <=s11 + carry10; 
                         s10 <=s10 - SHL64(carry10,21);
                    end
                    43: begin
                         carry11 <=s11 >>> 21;  // Use updated s11 value
                    end
                    44: begin
                         s12  <=s12 + carry11; 
                         s11 <=s11 - SHL64(carry11,21);
                    end
                    
                    // PROCESS STAGE 24 - s12 reduction
                    45: begin
                         s0 <=s0 + (s12 * 666643);
                         s1 <=s1 + (s12 * 470296);
                         s2 <=s2 + (s12 * 654183);
                         s3 <=s3 - (s12 * 997805);
                         s4 <=s4 + (s12 * 136657);
                         s5 <=s5 - (s12 * 683901);
                         s12 <=0;
                    end
                    
                    // Second carry propagation sequence (PROCESS STAGE 25, 26, 27)
                    46: begin
                         carry0 <=s0 >>> 21; 
                    end     
                    47: begin
                         s1  <=s1 + carry0; 
                         s0 <=s0 - SHL64(carry0,21);
                    end      
                    48: begin
                         carry1 <= s1  >>> 21;  // Use updated s1 value
                    end
                    49: begin
                         s2  <=s2 + carry1; 
                         s1 <=s1 - SHL64(carry1,21);
                    end
                    50: begin
                         carry2 <=s2  >>> 21;  // Use updated s2 value
                    end
                    51: begin
                         s3  <=s3 + carry2; 
                         s2 <=s2 - SHL64(carry2,21);
                    end
                    52: begin
                         carry3 <= s3 >>> 21;  // Use updated s3 value
                    end
                    53: begin
                         s4  <=s4 + carry3; 
                         s3 <=s3 - SHL64(carry3,21);
                    end
                    54: begin
                         carry4 <= s4 >>> 21;  // Use updated s4 value
                    end
                    55: begin
                         s5  <=s5 + carry4; 
                         s4 <=s4 - SHL64(carry4,21);
                    end
                    56: begin
                         carry5 <= s5  >>> 21;  // Use updated s5 value
                    end
                    57: begin
                         s6  <=s6 + carry5; 
                         s5 <=s5 - SHL64(carry5,21);
                    end
                    58: begin
                         carry6 <= s6  >>> 21;  // Use updated s6 value
                    end
                    59: begin
                         s7  <=s7 + carry6; 
                         s6 <=s6 - SHL64(carry6,21);
                    end
                    60: begin
                         carry7 <= s7  >>> 21;  // Use updated s7 value
                    end
                    61: begin
                         s8  <=s8 + carry7; 
                         s7 <=s7 - SHL64(carry7,21);
                    end
                    62: begin
                         carry8 <= s8  >>> 21;  // Use updated s8 value
                    end
                    63: begin
                         s9  <=s9 + carry8; 
                         s8 <=s8 - SHL64(carry8,21);
                    end
                    64: begin
                         carry9 <= s9 >>> 21;  // Use updated s9 value
                    end
                    65: begin
                         s10  <=s10 + carry9; 
                         s9 <=s9 - SHL64(carry9,21);
                    end
                    66: begin
                         carry10 <= s10  >>> 21;  // Use updated s10 value
                    end
                    67: begin
                         s11  <=s11 + carry10; 
                         s10 <=s10 - SHL64(carry10,21);
                         done_process <= 1;
                    end 
                endcase
                   if (!done_process) 
                   begin
                         cycle_counter <= cycle_counter + 1; // Increment counter
                   end
            end
        FINISH : begin
           // Final packing
                data_out[7:0] <=s0 >> 0;
                data_out[15:8] <=s0 >> 8;
                data_out[23:16] <=(s0 >> 16) | SHL64(s1,5);
                data_out[31:24] <=s1 >> 3;
                data_out[39:32] <=s1 >> 11;
                data_out[47:40] <=(s1 >> 19) | SHL64(s2,2);
                data_out[55:48] <=s2 >> 6;
                data_out[63:56] <=(s2 >> 14) | SHL64(s3,7);
                data_out[71:64]  <=s3 >> 1;
                data_out[79:72] <=s3 >> 9;
                data_out[87:80] <=(s3 >> 17) | SHL64(s4,4);
                data_out[95:88] <=s4 >> 4;
                data_out[103:96] <=s4 >> 12;
                data_out[111:104] <=(s4 >> 20) | SHL64(s5,1);
                data_out[119:112] <=s5 >> 7;
                data_out[127:120] <=(s5 >> 15) | SHL64(s6,6);
                data_out[135:128] <=s6 >> 2;
                data_out[143:136] <=s6 >> 10;
                data_out[151:144] <=(s6 >> 18) | SHL64(s7,3);
                data_out[159:152] <=s7 >> 5;
                data_out[167:160] <=s7 >> 13;
                data_out[175:168] <=s8 >> 0;
                data_out[183:176] <=s8 >> 8;
                data_out[191:184] <=(s8 >> 16) | SHL64(s9,5);
                data_out[199:192] <=s9 >> 3;
                data_out[207:200] <=s9 >> 11;
                data_out[215:208] <=(s9 >> 19) | SHL64(s10,2);
                data_out[223:216] <=s10 >> 6;
                data_out[231:224] <=(s10 >> 14) | SHL64(s11,7);
                data_out[239:232] <=s11 >> 1;
                data_out[247:240] <=s11 >> 9;
                data_out[255:248] <=s11 >> 17;
                done <=1;
        end
        default : begin
                data_out <=0;

        cycle_counter <=0;
        done <=0;
        done_process <=0;

        s0 <=0; s1 <=0; s2 <=0; s3 <=0; s4 <=0; s5 <=0; s6 <=0; s7 <=0;
        s8 <=0; s9 <=0; s10 <=0; s11 <=0; s12 <=0; s13 <=0; s14 <=0;
        s15 <=0; s16 <=0; s17 <=0; s18 <=0; s19 <=0; s20 <=0; s21 <=0;
        s22 <=0; s23 <=0;

        carry0 <=0; carry1 <=0; carry2 <=0; carry3 <=0; carry4 <=0; carry5 <=0; carry6 <=0; 
        carry7 <=0; carry8 <=0; carry9 <=0; carry10 <=0; carry11 <=0; carry12 <=0; carry13 <=0;
         carry14 <=0;carry15 <=0; carry16 <=0;
            end
    endcase
 end
end 
endmodule