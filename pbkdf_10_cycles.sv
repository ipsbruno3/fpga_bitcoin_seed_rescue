
`timescale 1ns/1ps

module test;
    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;

    wire [511:0] seed_out;
    wire done;

    // Expected PBKDF2-HMAC-SHA512("mnemonic", "mnemonic", 2048 iterations, 64 bytes)
    localparam [511:0] EXPECT =
        512'h7ddd60748d5e7cfc8f6c823df5c2956e14365245e2c8bba5ea732bbd790392a3ef5bdd731380072dd54f50923a7164ea502acf9d74cd794570252cc64bc7f744;

    pbkdf2_hmac_sha512_mnemonic dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .seed_out(seed_out),
        .done(done)
    );

    always #5 clk = ~clk;  // 100 MHz clock (period 10 ns)

    initial begin
        // Generous timeout
        #2000000;
        $display("TIMEOUT: done signal did not arrive.");
        $finish;
    end

    initial begin
        $display("BEGIN");

        rst_n = 0;
        #20 rst_n = 1;

        #20 start = 1;
        #10 start = 0;

        wait(done);
        $display("DONE at t=%0t ns", $time);
        $display("OUTPUT   = %h", seed_out);
        $display("EXPECTED = %h", EXPECT);

        if (seed_out === EXPECT) $display("PASS ✅");
        else                    $display("FAIL ❌");

        $finish;
    end
endmodule



module pbkdf2_hmac_sha512_mnemonic (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output logic [63:0] seed_out,
    output logic        done
);
    localparam [63:0] IPAD64 = 64'h3636363636363636;
    localparam [63:0] OPAD64 = 64'h5c5c5c5c5c5c5c5c;

    localparam [63:0] MNEM = 64'h6d6e656d6f6e6963;

    localparam [511:0] IV =
        512'h6a09e667f3bcc908bb67ae8584caa73b3c6ef372fe94f82ba54ff53a5f1d36f1510e527fade682d19b05688c2b3e6c1f1f83d9abfb41bd6b5be0cd19137e2179;

    localparam [11:0] ITER_MAX = 12'd2048;

    localparam [1023:0] INNER1 = { (MNEM ^ IPAD64), {15{IPAD64}} };
    localparam [1023:0] OUTER1 = { (MNEM ^ OPAD64), {15{OPAD64}} };

    localparam [1023:0] INNER2_SALT = {
        MNEM,
        64'h0000000180000000,
        {13{64'h0000000000000000}},
        64'd1120
    };

    function automatic [1023:0] pack_digest_block(input [511:0] dig);
        begin
            pack_digest_block = {
                dig,
                64'h8000000000000000,
                {6{64'h0000000000000000}},
                64'd1536
            };
        end
    endfunction

    // -------------------------
    // SHA engine (10 ciclos)
    // -------------------------
    logic          sha_start;
    logic [1023:0] sha_msg;
    logic [511:0]  sha_hin;
    wire  [511:0]  sha_hash;
    wire           sha_done;

    sha512_10cycle sha_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(sha_start),
        .message_in(sha_msg),
        .hash_in(sha_hin),
        .hash_out(sha_hash),
        .done(sha_done)
    );

    logic [511:0] GU, OU;
    logic [511:0] T;
    logic [11:0]  iter;

    typedef enum logic [2:0] {
        S_IDLE          = 3'd0,
        S_WAIT_INNER1   = 3'd1,
        S_WAIT_OUTER1   = 3'd2,
        S_WAIT_INNER_U1 = 3'd3,
        S_WAIT_OUTER_U1 = 3'd4,
        S_WAIT_INNER_IT = 3'd5,
        S_WAIT_OUTER_IT = 3'd6
    } state_t;

    state_t state;

    // ✅ combinacional: "próximo T" (XOR)
    wire [511:0] tnext_w = T ^ sha_hash;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            done     <= 1'b0;
            seed_out <= 64'd0;

            sha_start <= 1'b0;
            sha_msg   <= '0;
            sha_hin   <= '0;

            GU   <= '0;
            OU   <= '0;
            T    <= '0;
            iter <= 12'd0;
        end else begin
            done      <= 1'b0;
            sha_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        T    <= '0;
                        iter <= 12'd0;

                        sha_msg   <= INNER1;
                        sha_hin   <= IV;
                        sha_start <= 1'b1;
                        state     <= S_WAIT_INNER1;
                    end
                end

                S_WAIT_INNER1: begin
                    if (sha_done) begin
                        GU <= sha_hash;

                        sha_msg   <= OUTER1;
                        sha_hin   <= IV;
                        sha_start <= 1'b1;
                        state     <= S_WAIT_OUTER1;
                    end
                end

                S_WAIT_OUTER1: begin
                    if (sha_done) begin
                        OU <= sha_hash;

                        sha_msg   <= INNER2_SALT;
                        sha_hin   <= GU;
                        sha_start <= 1'b1;
                        state     <= S_WAIT_INNER_U1;
                    end
                end

                S_WAIT_INNER_U1: begin
                    if (sha_done) begin
                        sha_msg   <= pack_digest_block(sha_hash);
                        sha_hin   <= OU;
                        sha_start <= 1'b1;
                        state     <= S_WAIT_OUTER_U1;
                    end
                end

                S_WAIT_OUTER_U1: begin
                    if (sha_done) begin
                        T    <= sha_hash;   // U1
                        iter <= 12'd2;

                        sha_msg   <= pack_digest_block(sha_hash);
                        sha_hin   <= GU;
                        sha_start <= 1'b1;
                        state     <= S_WAIT_INNER_IT;
                    end
                end

                S_WAIT_INNER_IT: begin
                    if (sha_done) begin
                        sha_msg   <= pack_digest_block(sha_hash);
                        sha_hin   <= OU;
                        sha_start <= 1'b1;
                        state     <= S_WAIT_OUTER_IT;
                    end
                end

                S_WAIT_OUTER_IT: begin
                    if (sha_done) begin
                        if (iter == ITER_MAX) begin
                            seed_out <= tnext_w[63:0];   // ✅ usa o XOR já pronto
                            done     <= 1'b1;
                            state    <= S_IDLE;
                        end else begin
                            T    <= tnext_w;             // ✅ atualiza acumulador
                            iter <= iter + 12'd1;

                            sha_msg   <= pack_digest_block(sha_hash);
                            sha_hin   <= GU;
                            sha_start <= 1'b1;
                            state     <= S_WAIT_INNER_IT;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


module sha512_10cycle (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    input  wire [1023:0] message_in, // 16x64 big-endian (W0..W15)
    input  wire [511:0]  hash_in,     // H0..H7
    output reg  [511:0]  hash_out,
    output reg           done
);

    // ============================================================
    // K constants (modo compatível com simuladores antigos)
    // ============================================================
    reg [63:0] K [0:79];
    initial begin
        K[ 0]=64'h428a2f98d728ae22; K[ 1]=64'h7137449123ef65cd; K[ 2]=64'hb5c0fbcfec4d3b2f; K[ 3]=64'he9b5dba58189dbbc;
        K[ 4]=64'h3956c25bf348b538; K[ 5]=64'h59f111f1b605d019; K[ 6]=64'h923f82a4af194f9b; K[ 7]=64'hab1c5ed5da6d8118;
        K[ 8]=64'hd807aa98a3030242; K[ 9]=64'h12835b0145706fbe; K[10]=64'h243185be4ee4b28c; K[11]=64'h550c7dc3d5ffb4e2;
        K[12]=64'h72be5d74f27b896f; K[13]=64'h80deb1fe3b1696b1; K[14]=64'h9bdc06a725c71235; K[15]=64'hc19bf174cf692694;
        K[16]=64'he49b69c19ef14ad2; K[17]=64'hefbe4786384f25e3; K[18]=64'h0fc19dc68b8cd5b5; K[19]=64'h240ca1cc77ac9c65;
        K[20]=64'h2de92c6f592b0275; K[21]=64'h4a7484aa6ea6e483; K[22]=64'h5cb0a9dcbd41fbd4; K[23]=64'h76f988da831153b5;
        K[24]=64'h983e5152ee66dfab; K[25]=64'ha831c66d2db43210; K[26]=64'hb00327c898fb213f; K[27]=64'hbf597fc7beef0ee4;
        K[28]=64'hc6e00bf33da88fc2; K[29]=64'hd5a79147930aa725; K[30]=64'h06ca6351e003826f; K[31]=64'h142929670a0e6e70;
        K[32]=64'h27b70a8546d22ffc; K[33]=64'h2e1b21385c26c926; K[34]=64'h4d2c6dfc5ac42aed; K[35]=64'h53380d139d95b3df;
        K[36]=64'h650a73548baf63de; K[37]=64'h766a0abb3c77b2a8; K[38]=64'h81c2c92e47edaee6; K[39]=64'h92722c851482353b;
        K[40]=64'ha2bfe8a14cf10364; K[41]=64'ha81a664bbc423001; K[42]=64'hc24b8b70d0f89791; K[43]=64'hc76c51a30654be30;
        K[44]=64'hd192e819d6ef5218; K[45]=64'hd69906245565a910; K[46]=64'hf40e35855771202a; K[47]=64'h106aa07032bbd1b8;
        K[48]=64'h19a4c116b8d2d0c8; K[49]=64'h1e376c085141ab53; K[50]=64'h2748774cdf8eeb99; K[51]=64'h34b0bcb5e19b48a8;
        K[52]=64'h391c0cb3c5c95a63; K[53]=64'h4ed8aa4ae3418acb; K[54]=64'h5b9cca4f7763e373; K[55]=64'h682e6ff3d6b2b8a3;
        K[56]=64'h748f82ee5defb2fc; K[57]=64'h78a5636f43172f60; K[58]=64'h84c87814a1f0ab72; K[59]=64'h8cc702081a6439ec;
        K[60]=64'h90befffa23631e28; K[61]=64'ha4506cebde82bde9; K[62]=64'hbef9a3f7b2c67915; K[63]=64'hc67178f2e372532b;
        K[64]=64'hca273eceea26619c; K[65]=64'hd186b8c721c0c207; K[66]=64'heada7dd6cde0eb1e; K[67]=64'hf57d4f7fee6ed178;
        K[68]=64'h06f067aa72176fba; K[69]=64'h0a637dc5a2c898a6; K[70]=64'h113f9804bef90dae; K[71]=64'h1b710b35131c471b;
        K[72]=64'h28db77f523047d84; K[73]=64'h32caab7b40c72493; K[74]=64'h3c9ebe0a15c9bebc; K[75]=64'h431d67c49c100d4c;
        K[76]=64'h4cc5d4becb3e42b6; K[77]=64'h597f299cfc657e2a; K[78]=64'h5fcb6fab3ad6faec; K[79]=64'h6c44198c4a475817;
    end

    // ============================================================
    // regs / state
    // ============================================================
    reg [511:0] hin_reg;

    reg [63:0] W0_r, W1_r, W2_r, W3_r, W4_r, W5_r, W6_r, W7_r;
    reg [63:0] W8_r, W9_r, W10_r, W11_r, W12_r, W13_r, W14_r, W15_r;

    reg [63:0] W0_n, W1_n, W2_n, W3_n, W4_n, W5_n, W6_n, W7_n;
    reg [63:0] W8_n, W9_n, W10_n, W11_n, W12_n, W13_n, W14_n, W15_n;

    reg [63:0] wv0, wv1, wv2, wv3, wv4, wv5, wv6, wv7;
    reg        do_wupd;

    reg        busy;
    reg [3:0]  grp; 

    reg [63:0] a_r,b_r,c_r,d_r,e_r,f_r,g_r,h_r;
    reg [63:0] a_n,b_n,c_n,d_n,e_n,f_n,g_n,h_n;

    wire [63:0] H0o = hin_reg[511:448];
    wire [63:0] H1o = hin_reg[447:384];
    wire [63:0] H2o = hin_reg[383:320];
    wire [63:0] H3o = hin_reg[319:256];
    wire [63:0] H4o = hin_reg[255:192];
    wire [63:0] H5o = hin_reg[191:128];
    wire [63:0] H6o = hin_reg[127:64];
    wire [63:0] H7o = hin_reg[63:0];

    function automatic [63:0] rotr(input [63:0] x, input integer n);
        begin
            rotr = (x >> n) | (x << (64-n));
        end
    endfunction

    function automatic [63:0] Ch(input [63:0] x, input [63:0] y, input [63:0] z);
        begin
            Ch = (x & y) ^ (~x & z);
        end
    endfunction


    function automatic [63:0] SIG0(input [63:0] x);
        begin
            SIG0 = rotr(x,28) ^ rotr(x,34) ^ rotr(x,39);
        end
    endfunction

    function automatic [63:0] SIG1(input [63:0] x);
        begin
            SIG1 = rotr(x,14) ^ rotr(x,18) ^ rotr(x,41);
        end
    endfunction

    function automatic [63:0] s0(input [63:0] x);
        begin
            s0 = rotr(x,1) ^ rotr(x,8) ^ (x >> 7);
        end
    endfunction

    function automatic [63:0] s1(input [63:0] x);
        begin
            s1 = rotr(x,19) ^ rotr(x,61) ^ (x >> 6);
        end
    endfunction
  
    always @* begin
        // defaults
        wv0=64'd0; wv1=64'd0; wv2=64'd0; wv3=64'd0;
        wv4=64'd0; wv5=64'd0; wv6=64'd0; wv7=64'd0;

        W0_n=W0_r; W1_n=W1_r; W2_n=W2_r; W3_n=W3_r;
        W4_n=W4_r; W5_n=W5_r; W6_n=W6_r; W7_n=W7_r;
        W8_n=W8_r; W9_n=W9_r; W10_n=W10_r; W11_n=W11_r;
        W12_n=W12_r; W13_n=W13_r; W14_n=W14_r; W15_n=W15_r;

        do_wupd = 1'b0;

        if (busy) begin
            if (grp == 4'd0) begin
                wv0=W0_r; wv1=W1_r; wv2=W2_r; wv3=W3_r;
                wv4=W4_r; wv5=W5_r; wv6=W6_r; wv7=W7_r;
            end else if (grp == 4'd1) begin
                wv0=W8_r;  wv1=W9_r;  wv2=W10_r; wv3=W11_r;
                wv4=W12_r; wv5=W13_r; wv6=W14_r; wv7=W15_r;
            end else begin
                do_wupd = 1'b1;

                // wv0 = W0 + s0(W1) + W9 + s1(W14)
                wv0 = W0_r
                    + ( ({W1_r[0],W1_r[63:1]} ^ {W1_r[7:0],W1_r[63:8]} ^ (W1_r >> 7)) )
                    + W9_r
                    + ( ({W14_r[18:0],W14_r[63:19]} ^ {W14_r[60:0],W14_r[63:61]} ^ (W14_r >> 6)) );

                // wv1 = W1 + s0(W2) + W10 + s1(W15)
                wv1 = W1_r
                    + ( ({W2_r[0],W2_r[63:1]} ^ {W2_r[7:0],W2_r[63:8]} ^ (W2_r >> 7)) )
                    + W10_r
                    + ( ({W15_r[18:0],W15_r[63:19]} ^ {W15_r[60:0],W15_r[63:61]} ^ (W15_r >> 6)) );

                // wv2 = W2 + s0(W3) + W11 + s1(wv0)
                wv2 = W2_r
                    + ( ({W3_r[0],W3_r[63:1]} ^ {W3_r[7:0],W3_r[63:8]} ^ (W3_r >> 7)) )
                    + W11_r
                    + ( ({wv0[18:0],wv0[63:19]} ^ {wv0[60:0],wv0[63:61]} ^ (wv0 >> 6)) );

                // wv3 = W3 + s0(W4) + W12 + s1(wv1)
                wv3 = W3_r
                    + ( ({W4_r[0],W4_r[63:1]} ^ {W4_r[7:0],W4_r[63:8]} ^ (W4_r >> 7)) )
                    + W12_r
                    + ( ({wv1[18:0],wv1[63:19]} ^ {wv1[60:0],wv1[63:61]} ^ (wv1 >> 6)) );

                // wv4 = W4 + s0(W5) + W13 + s1(wv2)
                wv4 = W4_r
                    + ( ({W5_r[0],W5_r[63:1]} ^ {W5_r[7:0],W5_r[63:8]} ^ (W5_r >> 7)) )
                    + W13_r
                    + ( ({wv2[18:0],wv2[63:19]} ^ {wv2[60:0],wv2[63:61]} ^ (wv2 >> 6)) );

                // wv5 = W5 + s0(W6) + W14 + s1(wv3)
                wv5 = W5_r
                    + ( ({W6_r[0],W6_r[63:1]} ^ {W6_r[7:0],W6_r[63:8]} ^ (W6_r >> 7)) )
                    + W14_r
                    + ( ({wv3[18:0],wv3[63:19]} ^ {wv3[60:0],wv3[63:61]} ^ (wv3 >> 6)) );

                // wv6 = W6 + s0(W7) + W15 + s1(wv4)
                wv6 = W6_r
                    + ( ({W7_r[0],W7_r[63:1]} ^ {W7_r[7:0],W7_r[63:8]} ^ (W7_r >> 7)) )
                    + W15_r
                    + ( ({wv4[18:0],wv4[63:19]} ^ {wv4[60:0],wv4[63:61]} ^ (wv4 >> 6)) );

                // wv7 = W7 + s0(W8) + wv0 + s1(wv5)
                wv7 = W7_r
                    + ( ({W8_r[0],W8_r[63:1]} ^ {W8_r[7:0],W8_r[63:8]} ^ (W8_r >> 7)) )
                    + wv0
                    + ( ({wv5[18:0],wv5[63:19]} ^ {wv5[60:0],wv5[63:61]} ^ (wv5 >> 6)) );

                // próxima janela = W8..W15 + wv0..wv7
                W0_n  = W8_r;   W1_n  = W9_r;   W2_n  = W10_r;  W3_n  = W11_r;
                W4_n  = W12_r;  W5_n  = W13_r;  W6_n  = W14_r;  W7_n  = W15_r;
                W8_n  = wv0;    W9_n  = wv1;    W10_n = wv2;    W11_n = wv3;
                W12_n = wv4;    W13_n = wv5;    W14_n = wv6;    W15_n = wv7;
            end
        end
    end

	reg [63:0] a,b,c,d,e,f,g,h,aAndB,aOld,eFix,aOldRefix;
	reg [63:0] t1, t2;
	integer base;
  
        always @* begin
            // defaults: evita latch
            a = a_r; b = b_r; c = c_r; d = d_r;
            e = e_r; f = f_r; g = g_r; h = h_r;
        
            // IMPORTANTÍSSIMO: defaults pros "next" (senão vira latch)
            a_n = a_r; b_n = b_r; c_n = c_r; d_n = d_r;
            e_n = e_r; f_n = f_r; g_n = g_r; h_n = h_r;
        if (busy) begin
base = grp * 8;			
           
          aAndB = a & b;

          // ---------------- Rodadas 0-1 ----------------
          t1 = h + SIG1(e) + Ch(e,f,g) + K[base+0] + wv0;
          t2 = SIG0(a) + (aAndB ^ (a & c) ^ (b & c));

          eFix = d + t1;
          aOld = a;
          a = t1 + t2;

          t1 = g + SIG1(eFix) + Ch(eFix, e, f) + K[base+1] + wv1;
          t2 = SIG0(a) + ((a & aOld) ^ (a & b) ^ aAndB);
          h=f; g=e; f=eFix; e=c + t1; d=b; c=aOld; b=a; aOldRefix=t1 + t2;
          aAndB = aOldRefix & b;

          // ---------------- Rodadas 2-3 ----------------
          t1 = h + SIG1(e) + Ch(e,f,g) + K[base+2] + wv2;
          t2 = SIG0(aOldRefix) + (aAndB ^ (aOldRefix & aOld) ^ (b & aOld));

          eFix = d + t1;
          aOld = aOldRefix;
          a = t1 + t2;

          t1 = g + SIG1(eFix) + Ch(eFix, e, f) + K[base+3] + wv3;
          t2 = SIG0(a) + ((a & aOld) ^ (a & b) ^ aAndB);
          h=f; g=e; f=eFix; e=c + t1; d=b; c=aOld; b=a; a=t1 + t2;
          aAndB = a & b;

          // ---------------- Rodadas 4-5 ----------------
          t1 = h + SIG1(e) + Ch(e,f,g) + K[base+4] + wv4;
          t2 = SIG0(a) + (aAndB ^ (a & c) ^ (b & c));

          eFix = d + t1;
          aOld = a;
          a = t1 + t2;

          t1 = g + SIG1(eFix) + Ch(eFix, e, f) + K[base+5] + wv5;
          t2 = SIG0(a) + ((a & aOld) ^ (a & b) ^ aAndB);
          h=f;
          g=e; f=eFix; e=c + t1; d=b; c=aOld; b=a; a=t1 + t2;
          aAndB = a & b;

          // ---------------- Rodadas 6-7 ----------------
          t1 = h + SIG1(e) + Ch(e,f,g) + K[base+6] + wv6;
         
          eFix = d + t1;
          aOld = a;
          a = t1 + SIG0(a) + (aAndB ^ (a & c) ^ (b & c));

          t1 = g + SIG1(eFix) + Ch(eFix, e, f) + K[base+7] + wv7;      
          a_n=t1 + SIG0(a) + ((a & aOld) ^ (a & b) ^ aAndB);
          
          b_n=a;
          c_n=aOld;
          d_n=b;
          e_n=c+t1;
          f_n=eFix;
          g_n=e; h_n=f;
        end
    end

    // ============================================================
    // Sequencial: 10 clocks total
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hin_reg <= 512'd0;

            W0_r<=0; W1_r<=0; W2_r<=0; W3_r<=0; W4_r<=0; W5_r<=0; W6_r<=0; W7_r<=0;
            W8_r<=0; W9_r<=0; W10_r<=0; W11_r<=0; W12_r<=0; W13_r<=0; W14_r<=0; W15_r<=0;

            busy <= 1'b0;
            grp  <= 4'd0;
            done <= 1'b0;
            hash_out <= 512'd0;

            a_r<=0; b_r<=0; c_r<=0; d_r<=0;
            e_r<=0; f_r<=0; g_r<=0; h_r<=0;

        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                hin_reg <= hash_in;

                // carrega W0..W15 (big-endian)
                W0_r  <= message_in[1023:960];
                W1_r  <= message_in[959:896];
                W2_r  <= message_in[895:832];
                W3_r  <= message_in[831:768];
                W4_r  <= message_in[767:704];
                W5_r  <= message_in[703:640];
                W6_r  <= message_in[639:576];
                W7_r  <= message_in[575:512];
                W8_r  <= message_in[511:448];
                W9_r  <= message_in[447:384];
                W10_r <= message_in[383:320];
                W11_r <= message_in[319:256];
                W12_r <= message_in[255:192];
                W13_r <= message_in[191:128];
                W14_r <= message_in[127:64];
                W15_r <= message_in[63:0];

                // init working vars
                a_r <= hash_in[511:448];
                b_r <= hash_in[447:384];
                c_r <= hash_in[383:320];
                d_r <= hash_in[319:256];
                e_r <= hash_in[255:192];
                f_r <= hash_in[191:128];
                g_r <= hash_in[127:64];
                h_r <= hash_in[63:0];

                grp  <= 4'd0;
                busy <= 1'b1;

            end else if (busy) begin
                // atualiza working vars (após 8 rounds)
                a_r <= a_n; b_r <= b_n; c_r <= c_n; d_r <= d_n;
                e_r <= e_n; f_r <= f_n; g_r <= g_n; h_r <= h_n;

                // atualiza janela do schedule quando grp>=2
                if (do_wupd) begin
                    W0_r<=W0_n; W1_r<=W1_n; W2_r<=W2_n; W3_r<=W3_n;
                    W4_r<=W4_n; W5_r<=W5_n; W6_r<=W6_n; W7_r<=W7_n;
                    W8_r<=W8_n; W9_r<=W9_n; W10_r<=W10_n; W11_r<=W11_n;
                    W12_r<=W12_n; W13_r<=W13_n; W14_r<=W14_n; W15_r<=W15_n;
                end

                if (grp == 4'd9) begin
                    hash_out <= {
                        a_n + H0o, b_n + H1o, c_n + H2o, d_n + H3o,
                        e_n + H4o, f_n + H5o, g_n + H6o, h_n + H7o
                    };
                    done <= 1'b1;
                    busy <= 1'b0;
                    grp  <= 4'd0;
                end else begin
                    grp <= grp + 4'd1;
                end
            end
        end
    end

endmodule
