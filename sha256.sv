`timescale 1ns/1ps

module sha256_firstbyte_128 (
  input        clk,
  input        rst_n,
  input        start,
  input [63:0] hi64,
  input [63:0] lo64,
  output reg [7:0] out_byte,
  output reg       done,
  output reg       busy
);

  localparam [31:0] H0 = 32'h6a09e667;
  localparam [31:0] H1 = 32'hbb67ae85;
  localparam [31:0] H2 = 32'h3c6ef372;
  localparam [31:0] H3 = 32'ha54ff53a;
  localparam [31:0] H4 = 32'h510e527f;
  localparam [31:0] H5 = 32'h9b05688c;
  localparam [31:0] H6 = 32'h1f83d9ab;
  localparam [31:0] H7 = 32'h5be0cd19;

  function [31:0] rotr32;
    input [31:0] x;
    input [5:0]  n;
    begin
      rotr32 = (x >> n) | (x << (32 - n));
    end
  endfunction

  function [31:0] K256;
    input [5:0] t;
    begin
      case (t)
        6'd0:  K256 = 32'h428a2f98; 6'd1:  K256 = 32'h71374491; 6'd2:  K256 = 32'hb5c0fbcf; 6'd3:  K256 = 32'he9b5dba5;
        6'd4:  K256 = 32'h3956c25b; 6'd5:  K256 = 32'h59f111f1; 6'd6:  K256 = 32'h923f82a4; 6'd7:  K256 = 32'hab1c5ed5;
        6'd8:  K256 = 32'hd807aa98; 6'd9:  K256 = 32'h12835b01; 6'd10: K256 = 32'h243185be; 6'd11: K256 = 32'h550c7dc3;
        6'd12: K256 = 32'h72be5d74; 6'd13: K256 = 32'h80deb1fe; 6'd14: K256 = 32'h9bdc06a7; 6'd15: K256 = 32'hc19bf174;
        6'd16: K256 = 32'he49b69c1; 6'd17: K256 = 32'hefbe4786; 6'd18: K256 = 32'h0fc19dc6; 6'd19: K256 = 32'h240ca1cc;
        6'd20: K256 = 32'h2de92c6f; 6'd21: K256 = 32'h4a7484aa; 6'd22: K256 = 32'h5cb0a9dc; 6'd23: K256 = 32'h76f988da;
        6'd24: K256 = 32'h983e5152; 6'd25: K256 = 32'ha831c66d; 6'd26: K256 = 32'hb00327c8; 6'd27: K256 = 32'hbf597fc7;
        6'd28: K256 = 32'hc6e00bf3; 6'd29: K256 = 32'hd5a79147; 6'd30: K256 = 32'h06ca6351; 6'd31: K256 = 32'h14292967;
        6'd32: K256 = 32'h27b70a85; 6'd33: K256 = 32'h2e1b2138; 6'd34: K256 = 32'h4d2c6dfc; 6'd35: K256 = 32'h53380d13;
        6'd36: K256 = 32'h650a7354; 6'd37: K256 = 32'h766a0abb; 6'd38: K256 = 32'h81c2c92e; 6'd39: K256 = 32'h92722c85;
        6'd40: K256 = 32'ha2bfe8a1; 6'd41: K256 = 32'ha81a664b; 6'd42: K256 = 32'hc24b8b70; 6'd43: K256 = 32'hc76c51a3;
        6'd44: K256 = 32'hd192e819; 6'd45: K256 = 32'hd6990624; 6'd46: K256 = 32'hf40e3585; 6'd47: K256 = 32'h106aa070;
        6'd48: K256 = 32'h19a4c116; 6'd49: K256 = 32'h1e376c08; 6'd50: K256 = 32'h2748774c; 6'd51: K256 = 32'h34b0bcb5;
        6'd52: K256 = 32'h391c0cb3; 6'd53: K256 = 32'h4ed8aa4a; 6'd54: K256 = 32'h5b9cca4f; 6'd55: K256 = 32'h682e6ff3;
        6'd56: K256 = 32'h748f82ee; 6'd57: K256 = 32'h78a5636f; 6'd58: K256 = 32'h84c87814; 6'd59: K256 = 32'h8cc70208;
        6'd60: K256 = 32'h90befffa; 6'd61: K256 = 32'ha4506ceb; 6'd62: K256 = 32'hbef9a3f7; 6'd63: K256 = 32'hc67178f2;
        default: K256 = 32'h00000000;
      endcase
    end
  endfunction

  reg [31:0] a,b,c,d,e,f,g,h;
  reg [31:0] w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15;
  reg [5:0]  t;

  wire [31:0] Wt     = w0;

  wire [31:0] s0_w1  = rotr32(w1, 6'd7)  ^ rotr32(w1, 6'd18) ^ (w1 >> 3);
  wire [31:0] s1_w14 = rotr32(w14,6'd17) ^ rotr32(w14,6'd19) ^ (w14 >> 10);
  wire [31:0] newW   = s1_w14 + w9 + s0_w1 + w0;

  wire [31:0] S1e    = rotr32(e, 6'd6) ^ rotr32(e, 6'd11) ^ rotr32(e, 6'd25);
  wire [31:0] ch_efg = (e & f) ^ ((~e) & g);
  wire [31:0] temp1  = h + S1e + ch_efg + K256(t) + Wt;

  wire [31:0] S0a    = rotr32(a, 6'd2) ^ rotr32(a, 6'd13) ^ rotr32(a, 6'd22);
  wire [31:0] maj_abc= (a & b) ^ (a & c) ^ (b & c);
  wire [31:0] temp2  = S0a + maj_abc;

  wire [31:0] a_next = temp1 + temp2;
  wire [31:0] e_next = d + temp1;

  reg  [31:0] h0_plus_a;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy     <= 1'b0;
      done     <= 1'b0;
      out_byte <= 8'h00;
      t        <= 6'd0;
      a<=0; b<=0; c<=0; d<=0; e<=0; f<=0; g<=0; h<=0;
      w0<=0; w1<=0; w2<=0; w3<=0; w4<=0; w5<=0; w6<=0; w7<=0;
      w8<=0; w9<=0; w10<=0; w11<=0; w12<=0; w13<=0; w14<=0; w15<=0;
      h0_plus_a <= 32'h0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        busy <= 1'b1;
        t    <= 6'd0;

        w0  <= hi64[63:32];
        w1  <= hi64[31:0];
        w2  <= lo64[63:32];
        w3  <= lo64[31:0];
        w4  <= 32'h80000000;
        w5  <= 32'h00000000;
        w6  <= 32'h00000000;
        w7  <= 32'h00000000;
        w8  <= 32'h00000000;
        w9  <= 32'h00000000;
        w10 <= 32'h00000000;
        w11 <= 32'h00000000;
        w12 <= 32'h00000000;
        w13 <= 32'h00000000;
        w14 <= 32'h00000000;
        w15 <= 32'd128;

        a <= H0; b <= H1; c <= H2; d <= H3;
        e <= H4; f <= H5; g <= H6; h <= H7;
      end
      else if (busy) begin
        w0  <= w1;  w1  <= w2;  w2  <= w3;  w3  <= w4;
        w4  <= w5;  w5  <= w6;  w6  <= w7;  w7  <= w8;
        w8  <= w9;  w9  <= w10; w10 <= w11; w11 <= w12;
        w12 <= w13; w13 <= w14; w14 <= w15; w15 <= newW;

        h <= g;
        g <= f;
        f <= e;
        e <= e_next;
        d <= c;
        c <= b;
        b <= a;
        a <= a_next;

        if (t == 6'd63) begin
          h0_plus_a = H0 + a_next;
          out_byte <= h0_plus_a[31:24];
          done     <= 1'b1;
          busy     <= 1'b0;
        end else begin
          t <= t + 6'd1;
        end
      end
    end
  end

endmodule
