`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
//  Module Name: sha512_crypto
//  Engineer: Bruno da Silva @ipsbruno3
// 
//  Create Date: 28.12.2025 19:01:15
//  Project Name: bip39-pbkdf-verilog
//
//  Revision 0.01 - File Created
//  Comments: 
//  This code uses the same algorithm as Bitcoin Cracking in my other repository,  meaning that all optimization adjustments are being made. 
//  I'm initially testing with combinational cycles to run the seed tests in parallel, so each seed has a combinational process. 
//  If the clocks are not >200MHz on intermediate FPGAs, I will refactor the logic to work with pipelines.
//  For now we are only doing this for "mnemonic" entries (tests)
//
//////////////////////////////////////////////////////////////////////////////////

module tests;
    reg clk = 0;
    reg rst_n = 1;
    reg start = 0;

    wire [511:0] seed_out;
    wire done;

    pbkdf2_hmac_sha512_mnemonic dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .seed_out(seed_out),
        .done(done)
    );

    always #5 clk = ~clk;

    // Timeout para não travar se done nunca chegar
    initial begin
        #2000000; // 2 ms (timescale 1ns)
        $display("TIMEOUT: done nao chegou.");
        $finish;
    end

    initial begin
        $display("Simulation start");

        rst_n = 0;
        #20 rst_n = 1;

        #10 start = 1;
        #10 start = 0;

        // espera terminar
        wait(done);

        $display("==========================================");
        $display("DONE em t=%0t ns", $time);
        $display("BIP39 Seed para mnemonic 'mnemonic' (sem passphrase):");
        $display("%h", seed_out);
        $display("==========================================");
        $display("%h %h %h %h %h %h %h %h",
                 seed_out[511:448], seed_out[447:384], seed_out[383:320], seed_out[319:256],
                 seed_out[255:192], seed_out[191:128], seed_out[127:64], seed_out[63:0]);

        $finish;
    end
endmodule



module pbkdf2_hmac_sha512_mnemonic (
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg [511:0] seed_out,  // BIP39 seed final (64 bytes)
    output reg done
);

    localparam IDLE       = 3'd0,
               INIT_SALT  = 3'd1,
               U1_INNER   = 3'd2,
               U1_OUTER   = 3'd3,
               ITER_START = 3'd4,
               U_INNER    = 3'd5,
               U_OUTER    = 3'd6;
    // Bloco com salt "mnemonic" + 0x00000001 (big-endian) padded com zeros até 128 bytes
    reg [1023:0] first_block = 1024'h6d6e656d6f6e6963000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    
    reg [2:0] state;
    reg [11:0] iter;  // 0 a 4095 (agora cabe 2048)
    reg [511:0] U, T;

    wire [511:0] hash;
    reg [1023:0] message_in_reg;
    reg [511:0] hash_in_reg;

    sha512_pipeline sha_inst (
        .message_in(message_in_reg),
        .hash_in(hash_in_reg),
        .hash_out(hash)
    );

    // ipad e opad XOR com password "mnemonic" (padded para 128 bytes)
    localparam  BLOCK_BYTES = 128;
    localparam  BLOCK_BITS  = BLOCK_BYTES*8;
    
    // "mnemonic" = 8 bytes
    localparam [BLOCK_BITS-1:0] KEY_PAD =
        { "mnemonic", { (BLOCK_BYTES-8){8'h00} } };   // 8 + 120 = 128 bytes
    
    localparam [BLOCK_BITS-1:0] IPAD = { BLOCK_BYTES{8'h36} }; // 128 bytes de 0x36
    localparam [BLOCK_BITS-1:0] OPAD = { BLOCK_BYTES{8'h5c} }; // 128 bytes de 0x5c
    
    localparam [BLOCK_BITS-1:0] inner_block1 = KEY_PAD ^ IPAD;
    localparam [BLOCK_BITS-1:0] inner_block2 = IPAD;          
    localparam [BLOCK_BITS-1:0] outer_block1 = KEY_PAD ^ OPAD;
    localparam [BLOCK_BITS-1:0] outer_block2 = OPAD;

  always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iter <= 0;
            U <= 0;
            T <= 0;
            seed_out <= 0;
            done <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (start) state <= INIT_SALT;

                INIT_SALT: begin
                    message_in_reg <= first_block;
                    hash_in_reg <= 512'h6a09e667f3bcc908bb67ae8584caa73b3c6ef372fe94f82ba54ff53a5f1d36f1510e527fade682d19b05688c2b3e6c1f1f83d9abfb41bd6b5be0cd19137e2179;
                    state <= U1_INNER;
                end

                U1_INNER: begin
                    U <= hash;  // U1 parcial
                    message_in_reg <= outer_block1;
                    hash_in_reg <= 512'h6a09e667f3bcc908bb67ae8584caa73b3c6ef372fe94f82ba54ff53a5f1d36f1510e527fade682d19b05688c2b3e6c1f1f83d9abfb41bd6b5be0cd19137e2179;
                    state <= U1_OUTER;
                end

                U1_OUTER: begin
                    U <= hash;  // U1 completo
                    T <= hash;  // T = U1
                    iter <= 1;
                    state <= ITER_START;
                end

                ITER_START: begin
                    if (iter == 2048) begin  
                        seed_out <= T;
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        message_in_reg <= inner_block2;
                        hash_in_reg <= U;
                        state <= U_INNER;
                    end
                end

                U_INNER: begin
                    U <= hash;
                    message_in_reg <= outer_block2;
                    hash_in_reg <= U;
                    state <= U_OUTER;
                end

                U_OUTER: begin
                    U <= hash;
                    T <= T ^ hash;
                    iter <= iter + 1;
                    state <= ITER_START;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


module sha512_pipeline (
    input  wire [1023:0] message_in, // 16x64 (big-endian)
    input  wire [511:0]  hash_in,     // H0..H7
    output wire [511:0]  hash_out
);

    // -------------------------
    // Split H (big-endian)
    // -------------------------
    wire [63:0] H0 = hash_in[511:448];
    wire [63:0] H1 = hash_in[447:384];
    wire [63:0] H2 = hash_in[383:320];
    wire [63:0] H3 = hash_in[319:256];
    wire [63:0] H4 = hash_in[255:192];
    wire [63:0] H5 = hash_in[191:128];
    wire [63:0] H6 = hash_in[127:64];
    wire [63:0] H7 = hash_in[63:0];

    // -------------------------
    // W0..W15 (big-endian)
    // -------------------------
    wire [63:0] W0  = message_in[1023:960];
    wire [63:0] W1  = message_in[959:896];
    wire [63:0] W2  = message_in[895:832];
    wire [63:0] W3  = message_in[831:768];
    wire [63:0] W4  = message_in[767:704];
    wire [63:0] W5  = message_in[703:640];
    wire [63:0] W6  = message_in[639:576];
    wire [63:0] W7  = message_in[575:512];
    wire [63:0] W8  = message_in[511:448];
    wire [63:0] W9  = message_in[447:384];
    wire [63:0] W10 = message_in[383:320];
    wire [63:0] W11 = message_in[319:256];
    wire [63:0] W12 = message_in[255:192];
    wire [63:0] W13 = message_in[191:128];
    wire [63:0] W14 = message_in[127:64];
    wire [63:0] W15 = message_in[63:0];

 

    // -------------------------
    // L0/L1 usando concat para rotr
    // -------------------------
    function automatic [63:0] L0(input [63:0] x);
        begin
            L0 = {x[0],    x[63:1]}  ^ {x[7:0],  x[63:8]}  ^ (x >> 7);
        end
    endfunction

    function automatic [63:0] L1(input [63:0] x);
        begin
            L1 = {x[18:0], x[63:19]} ^ {x[60:0], x[63:61]} ^ (x >> 6);
        end
    endfunction

    // -------------------------
    // RoR macro style (atualiza só d e h)
    // -------------------------
    task automatic RoR(
        inout [63:0] a, b, c, d, e, f, g, h,
        input [63:0] w,
        input [63:0] k
    );
        reg [63:0] S0, S1, ch, maj, t1, t2;
        begin
            S1 = {e[13:0], e[63:14]} ^ {e[17:0], e[63:18]} ^ {e[40:0], e[63:41]};
            ch = (e & f) ^ (~e & g);
            t1 = h + S1 + ch + k + w;

            S0 = {a[27:0], a[63:28]} ^ {a[33:0], a[63:34]} ^ {a[38:0], a[63:39]};
            maj = (a & b) ^ (a & c) ^ (b & c);
            t2 = S0 + maj;

            d = d + t1;
            h = t1 + t2;
        end
    endtask

    // -------------------------
    // W16..W79 e A0..A7 (procedurais)
    // -------------------------
    reg [63:0] W16, W17, W18, W19, W20, W21, W22, W23;
    reg [63:0] W24, W25, W26, W27, W28, W29, W30, W31;
    reg [63:0] W32, W33, W34, W35, W36, W37, W38, W39;
    reg [63:0] W40, W41, W42, W43, W44, W45, W46, W47;
    reg [63:0] W48, W49, W50, W51, W52, W53, W54, W55;
    reg [63:0] W56, W57, W58, W59, W60, W61, W62, W63;
    reg [63:0] W64, W65, W66, W67, W68, W69, W70, W71;
    reg [63:0] W72, W73, W74, W75, W76, W77, W78, W79;

    reg [63:0] A0, A1, A2, A3, A4, A5, A6, A7;

    always @* begin
        // ---- W schedule (igual seu OpenCL) ----
        W16 = (W0  + L0(W1)  + W9  + L1(W14));
        W17 = (W1  + L0(W2)  + W10 + L1(W15));
        W18 = (W2  + L0(W3)  + W11 + L1(W16));
        W19 = (W3  + L0(W4)  + W12 + L1(W17));
        W20 = (W4  + L0(W5)  + W13 + L1(W18));
        W21 = (W5  + L0(W6)  + W14 + L1(W19));
        W22 = (W6  + L0(W7)  + W15 + L1(W20));
        W23 = (W7  + L0(W8)  + W16 + L1(W21));
        W24 = (W8  + L0(W9)  + W17 + L1(W22));
        W25 = (W9  + L0(W10) + W18 + L1(W23));
        W26 = (W10 + L0(W11) + W19 + L1(W24));
        W27 = (W11 + L0(W12) + W20 + L1(W25));
        W28 = (W12 + L0(W13) + W21 + L1(W26));
        W29 = (W13 + L0(W14) + W22 + L1(W27));
        W30 = (W14 + L0(W15) + W23 + L1(W28));
        W31 = (W15 + L0(W16) + W24 + L1(W29));

        W32 = (W16 + L0(W17) + W25 + L1(W30));
        W33 = (W17 + L0(W18) + W26 + L1(W31));
        W34 = (W18 + L0(W19) + W27 + L1(W32));
        W35 = (W19 + L0(W20) + W28 + L1(W33));
        W36 = (W20 + L0(W21) + W29 + L1(W34));
        W37 = (W21 + L0(W22) + W30 + L1(W35));
        W38 = (W22 + L0(W23) + W31 + L1(W36));
        W39 = (W23 + L0(W24) + W32 + L1(W37));
        W40 = (W24 + L0(W25) + W33 + L1(W38));
        W41 = (W25 + L0(W26) + W34 + L1(W39));
        W42 = (W26 + L0(W27) + W35 + L1(W40));
        W43 = (W27 + L0(W28) + W36 + L1(W41));
        W44 = (W28 + L0(W29) + W37 + L1(W42));
        W45 = (W29 + L0(W30) + W38 + L1(W43));
        W46 = (W30 + L0(W31) + W39 + L1(W44));
        W47 = (W31 + L0(W32) + W40 + L1(W45));
        W48 = (W32 + L0(W33) + W41 + L1(W46));
        W49 = (W33 + L0(W34) + W42 + L1(W47));
        W50 = (W34 + L0(W35) + W43 + L1(W48));
        W51 = (W35 + L0(W36) + W44 + L1(W49));
        W52 = (W36 + L0(W37) + W45 + L1(W50));
        W53 = (W37 + L0(W38) + W46 + L1(W51));
        W54 = (W38 + L0(W39) + W47 + L1(W52));
        W55 = (W39 + L0(W40) + W48 + L1(W53));
        W56 = (W40 + L0(W41) + W49 + L1(W54));
        W57 = (W41 + L0(W42) + W50 + L1(W55));
        W58 = (W42 + L0(W43) + W51 + L1(W56));
        W59 = (W43 + L0(W44) + W52 + L1(W57));
        W60 = (W44 + L0(W45) + W53 + L1(W58));
        W61 = (W45 + L0(W46) + W54 + L1(W59));
        W62 = (W46 + L0(W47) + W55 + L1(W60));
        W63 = (W47 + L0(W48) + W56 + L1(W61));
        W64 = (W48 + L0(W49) + W57 + L1(W62));
        W65 = (W49 + L0(W50) + W58 + L1(W63));
        W66 = (W50 + L0(W51) + W59 + L1(W64));
        W67 = (W51 + L0(W52) + W60 + L1(W65));
        W68 = (W52 + L0(W53) + W61 + L1(W66));
        W69 = (W53 + L0(W54) + W62 + L1(W67));
        W70 = (W54 + L0(W55) + W63 + L1(W68));
        W71 = (W55 + L0(W56) + W64 + L1(W69));
        W72 = (W56 + L0(W57) + W65 + L1(W70));
        W73 = (W57 + L0(W58) + W66 + L1(W71));
        W74 = (W58 + L0(W59) + W67 + L1(W72));
        W75 = (W59 + L0(W60) + W68 + L1(W73));
        W76 = (W60 + L0(W61) + W69 + L1(W74));
        W77 = (W61 + L0(W62) + W70 + L1(W75));
        W78 = (W62 + L0(W63) + W71 + L1(W76));
        W79 = (W63 + L0(W64) + W72 + L1(W77));

        // ---- init A regs ----
        A0 = H0; A1 = H1; A2 = H2; A3 = H3;
        A4 = H4; A5 = H5; A6 = H6; A7 = H7;

        // ---- 80 rounds ("rotação de argumentos manualmente") ----
        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W0,  64'h428a2f98d728ae22);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W1,  64'h7137449123ef65cd);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W2,  64'hb5c0fbcfec4d3b2f);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W3,  64'he9b5dba58189dbbc);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W4,  64'h3956c25bf348b538);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W5,  64'h59f111f1b605d019);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W6,  64'h923f82a4af194f9b);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W7,  64'hab1c5ed5da6d8118);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W8,  64'hd807aa98a3030242);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W9,  64'h12835b0145706fbe);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W10, 64'h243185be4ee4b28c);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W11, 64'h550c7dc3d5ffb4e2);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W12, 64'h72be5d74f27b896f);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W13, 64'h80deb1fe3b1696b1);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W14, 64'h9bdc06a725c71235);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W15, 64'hc19bf174cf692694);

        // W16..W79:
        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W16, 64'he49b69c19ef14ad2);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W17, 64'hefbe4786384f25e3);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W18, 64'h0fc19dc68b8cd5b5);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W19, 64'h240ca1cc77ac9c65);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W20, 64'h2de92c6f592b0275);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W21, 64'h4a7484aa6ea6e483);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W22, 64'h5cb0a9dcbd41fbd4);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W23, 64'h76f988da831153b5);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W24, 64'h983e5152ee66dfab);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W25, 64'ha831c66d2db43210);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W26, 64'hb00327c898fb213f);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W27, 64'hbf597fc7beef0ee4);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W28, 64'hc6e00bf33da88fc2);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W29, 64'hd5a79147930aa725);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W30, 64'h06ca6351e003826f);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W31, 64'h142929670a0e6e70);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W32, 64'h27b70a8546d22ffc);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W33, 64'h2e1b21385c26c926);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W34, 64'h4d2c6dfc5ac42aed);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W35, 64'h53380d139d95b3df);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W36, 64'h650a73548baf63de);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W37, 64'h766a0abb3c77b2a8);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W38, 64'h81c2c92e47edaee6);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W39, 64'h92722c851482353b);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W40, 64'ha2bfe8a14cf10364);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W41, 64'ha81a664bbc423001);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W42, 64'hc24b8b70d0f89791);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W43, 64'hc76c51a30654be30);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W44, 64'hd192e819d6ef5218);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W45, 64'hd69906245565a910);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W46, 64'hf40e35855771202a);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W47, 64'h106aa07032bbd1b8);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W48, 64'h19a4c116b8d2d0c8);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W49, 64'h1e376c085141ab53);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W50, 64'h2748774cdf8eeb99);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W51, 64'h34b0bcb5e19b48a8);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W52, 64'h391c0cb3c5c95a63);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W53, 64'h4ed8aa4ae3418acb);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W54, 64'h5b9cca4f7763e373);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W55, 64'h682e6ff3d6b2b8a3);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W56, 64'h748f82ee5defb2fc);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W57, 64'h78a5636f43172f60);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W58, 64'h84c87814a1f0ab72);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W59, 64'h8cc702081a6439ec);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W60, 64'h90befffa23631e28);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W61, 64'ha4506cebde82bde9);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W62, 64'hbef9a3f7b2c67915);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W63, 64'hc67178f2e372532b);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W64, 64'hca273eceea26619c);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W65, 64'hd186b8c721c0c207);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W66, 64'heada7dd6cde0eb1e);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W67, 64'hf57d4f7fee6ed178);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W68, 64'h06f067aa72176fba);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W69, 64'h0a637dc5a2c898a6);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W70, 64'h113f9804bef90dae);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W71, 64'h1b710b35131c471b);

        RoR(A0, A1, A2, A3, A4, A5, A6, A7, W72, 64'h28db77f523047d84);
        RoR(A7, A0, A1, A2, A3, A4, A5, A6, W73, 64'h32caab7b40c72493);
        RoR(A6, A7, A0, A1, A2, A3, A4, A5, W74, 64'h3c9ebe0a15c9bebc);
        RoR(A5, A6, A7, A0, A1, A2, A3, A4, W75, 64'h431d67c49c100d4c);
        RoR(A4, A5, A6, A7, A0, A1, A2, A3, W76, 64'h4cc5d4becb3e42b6);
        RoR(A3, A4, A5, A6, A7, A0, A1, A2, W77, 64'h597f299cfc657e2a);
        RoR(A2, A3, A4, A5, A6, A7, A0, A1, W78, 64'h5fcb6fab3ad6faec);
        RoR(A1, A2, A3, A4, A5, A6, A7, A0, W79, 64'h6c44198c4a475817);

    end

    // ---- feed-forward final ----
    assign hash_out = {
        A0 + H0, A1 + H1, A2 + H2, A3 + H3,
        A4 + H4, A5 + H5, A6 + H6, A7 + H7
    };

endmodule
