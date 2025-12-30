//////////////////////////////////////////////////////////////////////////////////
//
//  Module Name: sha512_compress_pipe
//  Engineer: Bruno da Silva @ipsbruno3
// 
//  Create Date: 30.12.2025 17:11:00
//  Project Name: bip39-pbkdf-verilog
//
//  Revision 0.01 - File Created
//  Comments: 
//  This is an alternative SHA-512 implementation from the project, distinct from the other SHA-512 file. 
//  In this version, I prioritized LUT efficiency to enable more parallel lanes and cores by using a one-round-per-cycle compression architecture. 
//  On a mid-range FPGA, this design uses roughly 2,000 LUTs, which makes high core replication practical. 
//  For example, a Xilinx Artix-7 XC7A200T could fit approximately 45 cores, depending on routing, BRAM usage, and timing closure.
//
//////////////////////////////////////////////////////////////////////////////////

module sha512_compress_pipe (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,          // pulso 1 a
    output reg  [31:0]  H_out,          // H'0..H'7 big-endian
    output reg          done,            // pulso 1 ciclo
    output reg          busy
);
    wire [1023:0] block_in;
    wire [511:0]  H_in;
    
    // -------- helpers ----------
    function [63:0] rotr;
        input [63:0] x;
        input integer n;
        begin
            rotr = (x >> n) | (x << (64-n));
        end
    endfunction

    function [63:0] SIG0;
        input [63:0] x;
        begin SIG0 = rotr(x,28) ^ rotr(x,34) ^ rotr(x,39); end
    endfunction

    function [63:0] SIG1;
        input [63:0] x;
        begin SIG1 = rotr(x,14) ^ rotr(x,18) ^ rotr(x,41); end
    endfunction

    function [63:0] sig0;
        input [63:0] x;
        begin sig0 = rotr(x,1) ^ rotr(x,8) ^ (x >> 7); end
    endfunction

    function [63:0] sig1;
        input [63:0] x;
        begin sig1 = rotr(x,19) ^ rotr(x,61) ^ (x >> 6); end
    endfunction

    function [63:0] Ch;
        input [63:0] x,y,z;
        begin Ch = (x & y) ^ (~x & z); end
    endfunction

    function [63:0] Maj;
        input [63:0] x,y,z;
        begin Maj = (x & y) ^ (x & z) ^ (y & z); end
    endfunction

    // -------- K constants ROM ----------
    reg [63:0] K [0:79];
    integer i;
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

    // -------- state ----------
    reg [63:0] a,b,c,d,e,f,g,h;
    reg [63:0] H0b,H1b,H2b,H3b,H4b,H5b,H6b,H7b;

    reg [63:0] W [0:15];
    reg [6:0]  t;

    // split H_in big-endian
    wire [63:0] H0 = H_in[511:448];
    wire [63:0] H1 = H_in[447:384];
    wire [63:0] H2 = H_in[383:320];
    wire [63:0] H3 = H_in[319:256];
    wire [63:0] H4 = H_in[255:192];
    wire [63:0] H5 = H_in[191:128];
    wire [63:0] H6 = H_in[127:64];
    wire [63:0] H7 = H_in[63:0];

    // temporários
    reg [63:0] wt, w_new, t1v, t2v;
    reg [63:0] a_n,b_n,c_n,d_n,e_n,f_n,g_n,h_n;
    reg [3:0]  idx, idx2, idx7, idx15, idx16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            busy <= 1'b0;
            H_out <= 512'd0;
            t <= 7'd0;
            a<=0;b<=0;c<=0;d<=0;e<=0;f<=0;g<=0;h<=0;
            H0b<=0;H1b<=0;H2b<=0;H3b<=0;H4b<=0;H5b<=0;H6b<=0;H7b<=0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                // base H
                H0b <= H0; H1b <= H1; H2b <= H2; H3b <= H3;
                H4b <= H4; H5b <= H5; H6b <= H6; H7b <= H7;

                // init vars
                a <= H0; b <= H1; c <= H2; d <= H3;
                e <= H4; f <= H5; g <= H6; h <= H7;

                // load W0..W15 (sem -:)
                W[0]  <= block_in[1023:960];
                W[1]  <= block_in[959:896];
                W[2]  <= block_in[895:832];
                W[3]  <= block_in[831:768];
                W[4]  <= block_in[767:704];
                W[5]  <= block_in[703:640];
                W[6]  <= block_in[639:576];
                W[7]  <= block_in[575:512];
                W[8]  <= block_in[511:448];
                W[9]  <= block_in[447:384];
                W[10] <= block_in[383:320];
                W[11] <= block_in[319:256];
                W[12] <= block_in[255:192];
                W[13] <= block_in[191:128];
                W[14] <= block_in[127:64];
                W[15] <= block_in[63:0];

                t <= 7'd0;
                busy <= 1'b1;
            end
            else if (busy) begin
                idx   = t[3:0];
                idx2  = (t - 7'd2)  & 4'hF;
                idx7  = (t - 7'd7)  & 4'hF;
                idx15 = (t - 7'd15) & 4'hF;
                idx16 = (t - 7'd16) & 4'hF;

                w_new = 64'd0;
                if (t < 7'd16) begin
                    wt = W[idx];
                end else begin
                    w_new = sig1(W[idx2]) + W[idx7] + sig0(W[idx15]) + W[idx16];
                    wt    = w_new;
                end

                t1v = h + SIG1(e) + Ch(e,f,g) + K[t] + wt;
                t2v = SIG0(a) + Maj(a,b,c);

                a_n = t1v + t2v;
                b_n = a;
                c_n = b;
                d_n = c;
                e_n = d + t1v;
                f_n = e;
                g_n = f;
                h_n = g;

                if (t >= 7'd16) begin
                    W[idx] <= w_new;
                end

                a <= a_n; b <= b_n; c <= c_n; d <= d_n;
                e <= e_n; f <= f_n; g <= g_n; h <= h_n;

                if (t == 7'd79) begin
                    H_out <= {a_n + H0b};
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    t <= t + 7'd1;
                end
            end
        end
    end

endmodule
