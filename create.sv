
`include "bip39.sv"
`include "sha256.sv"


module pack_128plus4_to_12x11 (
  input  logic [63:0] hi64,
  input  logic [63:0] lo64,
  input  logic [3:0]  cs4,
  output logic [10:0] idx0,
  output logic [10:0] idx1,
  output logic [10:0] idx2,
  output logic [10:0] idx3,
  output logic [10:0] idx4,
  output logic [10:0] idx5,
  output logic [10:0] idx6,
  output logic [10:0] idx7,
  output logic [10:0] idx8,
  output logic [10:0] idx9,
  output logic [10:0] idx10,
  output logic [10:0] idx11
);
  wire [131:0] bits132;
  assign bits132 = {hi64, lo64, cs4};

  assign idx0  = bits132[131:121];
  assign idx1  = bits132[120:110];
  assign idx2  = bits132[109: 99];
  assign idx3  = bits132[ 98: 88];
  assign idx4  = bits132[ 87: 77];
  assign idx5  = bits132[ 76: 66];
  assign idx6  = bits132[ 65: 55];
  assign idx7  = bits132[ 54: 44];
  assign idx8  = bits132[ 43: 33];
  assign idx9  = bits132[ 32: 22];
  assign idx10 = bits132[ 21: 11];
  assign idx11 = bits132[ 10:  0];
endmodule


module words_stream_12 #(
  parameter int AW = 11,
  parameter int DW = 72
)(
  input  logic          clk,
  input  logic          rst_n,
  input  logic          start,

  input  logic [AW-1:0] idx0,
  input  logic [AW-1:0] idx1,
  input  logic [AW-1:0] idx2,
  input  logic [AW-1:0] idx3,
  input  logic [AW-1:0] idx4,
  input  logic [AW-1:0] idx5,
  input  logic [AW-1:0] idx6,
  input  logic [AW-1:0] idx7,
  input  logic [AW-1:0] idx8,
  input  logic [AW-1:0] idx9,
  input  logic [AW-1:0] idx10,
  input  logic [AW-1:0] idx11,

  output logic [DW-1:0] word_out,
  output logic          word_valid,
  output logic          done
);

  logic [AW-1:0] addr_q;
  logic [DW-1:0] rom_word;

  palavras_rom urom (
    .clk   (clk),
    .index (addr_q),
    .word  (rom_word)
  );

  function automatic logic [AW-1:0] sel_idx(input logic [3:0] k);
    begin
      case (k)
        4'd0:  sel_idx = idx0;
        4'd1:  sel_idx = idx1;
        4'd2:  sel_idx = idx2;
        4'd3:  sel_idx = idx3;
        4'd4:  sel_idx = idx4;
        4'd5:  sel_idx = idx5;
        4'd6:  sel_idx = idx6;
        4'd7:  sel_idx = idx7;
        4'd8:  sel_idx = idx8;
        4'd9:  sel_idx = idx9;
        4'd10: sel_idx = idx10;
        default: sel_idx = idx11;
      endcase
    end
  endfunction

  logic       busy;
  logic       primed;
  logic [3:0] load_ptr;
  logic [3:0] out_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr_q     <= '0;
      busy       <= 1'b0;
      primed     <= 1'b0;
      load_ptr   <= 4'd0;
      out_cnt    <= 4'd0;
      word_out   <= '0;
      word_valid <= 1'b0;
      done       <= 1'b0;
    end else begin
      word_valid <= 1'b0;

      // DONE sticky: só limpa no próximo start
      if (start) done <= 1'b0;

      if (!busy) begin
        if (start) begin
          busy     <= 1'b1;
          primed   <= 1'b0;
          out_cnt  <= 4'd0;
          addr_q   <= sel_idx(4'd0);
          load_ptr <= 4'd1;
        end
      end else begin
        word_out <= rom_word;

        if (!primed) begin
          primed <= 1'b1;
        end else begin
          word_valid <= 1'b1;

          if (out_cnt == 4'd11) begin
            done <= 1'b1;
            busy <= 1'b0;
          end else begin
            out_cnt <= out_cnt + 4'd1;
          end
        end

        if (load_ptr <= 4'd11) begin
          addr_q   <= sel_idx(load_ptr);
          load_ptr <= load_ptr + 4'd1;
        end
      end
    end
  end

endmodule


module words_from_128_top (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [63:0] hi64,
  input  logic [63:0] lo64,
  input  logic [3:0]  cs4,
  output logic [71:0] word_out,
  output logic        word_valid,
  output logic        done
);
  logic [10:0] idx0,idx1,idx2,idx3,idx4,idx5,idx6,idx7,idx8,idx9,idx10,idx11;

  pack_128plus4_to_12x11 u_pack (
    .hi64(hi64), .lo64(lo64), .cs4(cs4),
    .idx0(idx0), .idx1(idx1), .idx2(idx2), .idx3(idx3),
    .idx4(idx4), .idx5(idx5), .idx6(idx6), .idx7(idx7),
    .idx8(idx8), .idx9(idx9), .idx10(idx10), .idx11(idx11)
  );

  words_stream_12 u_stream (
    .clk(clk), .rst_n(rst_n), .start(start),
    .idx0(idx0), .idx1(idx1), .idx2(idx2), .idx3(idx3),
    .idx4(idx4), .idx5(idx5), .idx6(idx6), .idx7(idx7),
    .idx8(idx8), .idx9(idx9), .idx10(idx10), .idx11(idx11),
    .word_out(word_out), .word_valid(word_valid), .done(done)
  );
endmodule


module tb_words_stream_12;

  logic clk, rst_n, start;
  logic [63:0] hi64, lo64;
  logic [3:0]  cs4;
  logic [71:0] word_out;
  logic        word_valid, done;

  // SHA signals + instância
  logic        sha_start;
  logic [63:0] sha_hi, sha_lo;
  logic [7:0]  sha_byte;
  logic        sha_done, sha_busy;

  sha256_firstbyte_128 u_sha (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (sha_start),
    .hi64     (sha_hi),
    .lo64     (sha_lo),
    .out_byte (sha_byte),
    .done     (sha_done),
    .busy     (sha_busy)
  );

  words_from_128_top top (
    .clk(clk), .rst_n(rst_n), .start(start),
    .hi64(hi64), .lo64(lo64), .cs4(cs4),
    .word_out(word_out), .word_valid(word_valid), .done(done)
  );

  always #5 clk = ~clk;

  function automatic string word72_to_string(input logic [71:0] w);
    string s;
    integer j, k;
    logic [7:0] b;
    logic [7:0] bk;
    logic only_pad;
    begin
      s = "";
      for (j = 0; j < 8; j++) begin
        b = w[71 - (j*8) -: 8];
        if (b == 8'h00) return s;

        if (b == 8'h20) begin
          only_pad = 1'b1;
          for (k = j; k < 8; k++) begin
            bk = w[71 - (k*8) -: 8];
            if (bk != 8'h20 && bk != 8'h00) only_pad = 1'b0;
          end
          if (only_pad) return s;
        end

        s = {s, b};
      end
      return s;
    end
  endfunction

  task automatic run_one_case_128(
    input logic [63:0] in_hi,
    input logic [63:0] in_lo
  );
    integer count;
    string combo, w;
    logic [131:0] bits132;
    logic [10:0] d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11;
    logic [3:0] cs_calc;
    begin
      // calcula cs4 = SHA256(entropy)[7:4]
      sha_hi = in_hi;
      sha_lo = in_lo;

      @(negedge clk);
      sha_start = 1'b1;
      @(negedge clk);
      sha_start = 1'b0;

      wait(sha_done);
      cs_calc = sha_byte[7:4];

      // aplica no DUT
      hi64 = in_hi;
      lo64 = in_lo;
      cs4  = cs_calc;

      bits132 = {in_hi, in_lo, cs_calc};

      d0  = bits132[131:121];
      d1  = bits132[120:110];
      d2  = bits132[109: 99];
      d3  = bits132[ 98: 88];
      d4  = bits132[ 87: 77];
      d5  = bits132[ 76: 66];
      d6  = bits132[ 65: 55];
      d7  = bits132[ 54: 44];
      d8  = bits132[ 43: 33];
      d9  = bits132[ 32: 22];
      d10 = bits132[ 21: 11];
      d11 = bits132[ 10:  0];

      $display("CS4(calc)=%h  SHA_firstbyte=%02x", cs_calc, sha_byte);
      $display("IDX: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
               d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11);

      @(negedge clk);
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;

      count = 0;
      combo = "";

      while (count < 12) begin
        @(posedge clk);
        if (word_valid) begin
          w = word72_to_string(word_out);
          if (count == 0) combo = w;
          else            combo = {combo, " ", w};
          count = count + 1;
        end
      end

      wait(done); // agora done é sticky, não perde mais
      $display("[%0t] HI=%h LO=%h CS=%h", $time, in_hi, in_lo, cs_calc);
      $display("[%0t] COMBO = %s", $time, combo);
      $display("[%0t] DONE\n", $time);
    end
  endtask

  initial begin
    clk=0; rst_n=0; start=0;
    hi64=0; lo64=0; cs4=0;
    sha_start=0; sha_hi=0; sha_lo=0;

    repeat(5) @(negedge clk);
    rst_n = 1;

    run_one_case_128(64'hc66b30a6acf070f2, 64'h7ef0000000000001);
    run_one_case_128(64'hc66b30a6acf070f2, 64'h7ef0000000000002);

    $finish;
  end

endmodule
