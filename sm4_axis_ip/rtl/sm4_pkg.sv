////////////////////////////////////////////////////////////////////////////////
//
// Project Name        : SM4 AXI4-Stream IP
// Module Name         : sm4_pkg
// Creation Date       : 2026-11-25
// Author              : najam
//
// Function            :
//   Shared types, system constants and the combinational SM4 transforms.
//   S-box values, FK and CK follow GM/T 0002-2012 as reproduced in the
//   SM4_Presentation.pdf supplied with this project.
//
// HOW TO INITIALISE AND USE:
//   Import the package into each design unit. The functions are pure and
//   synthesizable; no state is kept here.
//
////////////////////////////////////////////////////////////////////////////////

`default_nettype none

package sm4_pkg;

  // ==========================================================================
  // 1. TYPES AND ROUND CONSTANTS
  // ==========================================================================

  typedef logic [31:0] word_t;
  typedef logic [127:0] block_t;
  typedef logic [31:0] rk_array_t [32];

  // System parameters FK, one word per key-schedule seed. Expressed as a
  // function rather than an unpacked-array parameter so every tool flow can
  // elaborate the package without special array-parameter support.
  function automatic word_t f_fk (input int unsigned i);
    case (i)
      0: f_fk = 32'hA3B1BAC6;
      1: f_fk = 32'h56AA3350;
      2: f_fk = 32'h677D9197;
      3: f_fk = 32'hB27022DC;
      default: f_fk = 32'h00000000;
    endcase
  endfunction

  // CK[i][j] = (4i + j) * 7 mod 256, packed as words.
  function automatic word_t f_ck (input int unsigned i);
    case (i)
      0:  f_ck = 32'h00070E15;  1:  f_ck = 32'h1C232A31;
      2:  f_ck = 32'h383F464D;  3:  f_ck = 32'h545B6269;
      4:  f_ck = 32'h70777E85;  5:  f_ck = 32'h8C939AA1;
      6:  f_ck = 32'hA8AFB6BD;  7:  f_ck = 32'hC4CBD2D9;
      8:  f_ck = 32'hE0E7EEF5;  9:  f_ck = 32'hFC030A11;
      10: f_ck = 32'h181F262D;  11: f_ck = 32'h343B4249;
      12: f_ck = 32'h50575E65;  13: f_ck = 32'h6C737A81;
      14: f_ck = 32'h888F969D;  15: f_ck = 32'hA4ABB2B9;
      16: f_ck = 32'hC0C7CED5;  17: f_ck = 32'hDCE3EAF1;
      18: f_ck = 32'hF8FF060D;  19: f_ck = 32'h141B2229;
      20: f_ck = 32'h30373E45;  21: f_ck = 32'h4C535A61;
      22: f_ck = 32'h686F767D;  23: f_ck = 32'h848B9299;
      24: f_ck = 32'hA0A7AEB5;  25: f_ck = 32'hBCC3CAD1;
      26: f_ck = 32'hD8DFE6ED;  27: f_ck = 32'hF4FB0209;
      28: f_ck = 32'h10171E25;  29: f_ck = 32'h2C333A41;
      30: f_ck = 32'h484F565D;  31: f_ck = 32'h646B7279;
      default: f_ck = 32'h00000000;
    endcase
  endfunction

  // ==========================================================================
  // 2. NON-LINEAR TRANSFORM TAU (S-BOX ON EACH BYTE)
  // ==========================================================================

  function automatic logic [7:0] f_sbox (input logic [7:0] x);
    case (x)
      8'h00: f_sbox = 8'hD6; 8'h01: f_sbox = 8'h90;
      8'h02: f_sbox = 8'hE9; 8'h03: f_sbox = 8'hFE;
      8'h04: f_sbox = 8'hCC; 8'h05: f_sbox = 8'hE1;
      8'h06: f_sbox = 8'h3D; 8'h07: f_sbox = 8'hB7;
      8'h08: f_sbox = 8'h16; 8'h09: f_sbox = 8'hB6;
      8'h0A: f_sbox = 8'h14; 8'h0B: f_sbox = 8'hC2;
      8'h0C: f_sbox = 8'h28; 8'h0D: f_sbox = 8'hFB;
      8'h0E: f_sbox = 8'h2C; 8'h0F: f_sbox = 8'h05;
      8'h10: f_sbox = 8'h2B; 8'h11: f_sbox = 8'h67;
      8'h12: f_sbox = 8'h9A; 8'h13: f_sbox = 8'h76;
      8'h14: f_sbox = 8'h2A; 8'h15: f_sbox = 8'hBE;
      8'h16: f_sbox = 8'h04; 8'h17: f_sbox = 8'hC3;
      8'h18: f_sbox = 8'hAA; 8'h19: f_sbox = 8'h44;
      8'h1A: f_sbox = 8'h13; 8'h1B: f_sbox = 8'h26;
      8'h1C: f_sbox = 8'h49; 8'h1D: f_sbox = 8'h86;
      8'h1E: f_sbox = 8'h06; 8'h1F: f_sbox = 8'h99;
      8'h20: f_sbox = 8'h9C; 8'h21: f_sbox = 8'h42;
      8'h22: f_sbox = 8'h50; 8'h23: f_sbox = 8'hF4;
      8'h24: f_sbox = 8'h91; 8'h25: f_sbox = 8'hEF;
      8'h26: f_sbox = 8'h98; 8'h27: f_sbox = 8'h7A;
      8'h28: f_sbox = 8'h33; 8'h29: f_sbox = 8'h54;
      8'h2A: f_sbox = 8'h0B; 8'h2B: f_sbox = 8'h43;
      8'h2C: f_sbox = 8'hED; 8'h2D: f_sbox = 8'hCF;
      8'h2E: f_sbox = 8'hAC; 8'h2F: f_sbox = 8'h62;
      8'h30: f_sbox = 8'hE4; 8'h31: f_sbox = 8'hB3;
      8'h32: f_sbox = 8'h1C; 8'h33: f_sbox = 8'hA9;
      8'h34: f_sbox = 8'hC9; 8'h35: f_sbox = 8'h08;
      8'h36: f_sbox = 8'hE8; 8'h37: f_sbox = 8'h95;
      8'h38: f_sbox = 8'h80; 8'h39: f_sbox = 8'hDF;
      8'h3A: f_sbox = 8'h94; 8'h3B: f_sbox = 8'hFA;
      8'h3C: f_sbox = 8'h75; 8'h3D: f_sbox = 8'h8F;
      8'h3E: f_sbox = 8'h3F; 8'h3F: f_sbox = 8'hA6;
      8'h40: f_sbox = 8'h47; 8'h41: f_sbox = 8'h07;
      8'h42: f_sbox = 8'hA7; 8'h43: f_sbox = 8'hFC;
      8'h44: f_sbox = 8'hF3; 8'h45: f_sbox = 8'h73;
      8'h46: f_sbox = 8'h17; 8'h47: f_sbox = 8'hBA;
      8'h48: f_sbox = 8'h83; 8'h49: f_sbox = 8'h59;
      8'h4A: f_sbox = 8'h3C; 8'h4B: f_sbox = 8'h19;
      8'h4C: f_sbox = 8'hE6; 8'h4D: f_sbox = 8'h85;
      8'h4E: f_sbox = 8'h4F; 8'h4F: f_sbox = 8'hA8;
      8'h50: f_sbox = 8'h68; 8'h51: f_sbox = 8'h6B;
      8'h52: f_sbox = 8'h81; 8'h53: f_sbox = 8'hB2;
      8'h54: f_sbox = 8'h71; 8'h55: f_sbox = 8'h64;
      8'h56: f_sbox = 8'hDA; 8'h57: f_sbox = 8'h8B;
      8'h58: f_sbox = 8'hF8; 8'h59: f_sbox = 8'hEB;
      8'h5A: f_sbox = 8'h0F; 8'h5B: f_sbox = 8'h4B;
      8'h5C: f_sbox = 8'h70; 8'h5D: f_sbox = 8'h56;
      8'h5E: f_sbox = 8'h9D; 8'h5F: f_sbox = 8'h35;
      8'h60: f_sbox = 8'h1E; 8'h61: f_sbox = 8'h24;
      8'h62: f_sbox = 8'h0E; 8'h63: f_sbox = 8'h5E;
      8'h64: f_sbox = 8'h63; 8'h65: f_sbox = 8'h58;
      8'h66: f_sbox = 8'hD1; 8'h67: f_sbox = 8'hA2;
      8'h68: f_sbox = 8'h25; 8'h69: f_sbox = 8'h22;
      8'h6A: f_sbox = 8'h7C; 8'h6B: f_sbox = 8'h3B;
      8'h6C: f_sbox = 8'h01; 8'h6D: f_sbox = 8'h21;
      8'h6E: f_sbox = 8'h78; 8'h6F: f_sbox = 8'h87;
      8'h70: f_sbox = 8'hD4; 8'h71: f_sbox = 8'h00;
      8'h72: f_sbox = 8'h46; 8'h73: f_sbox = 8'h57;
      8'h74: f_sbox = 8'h9F; 8'h75: f_sbox = 8'hD3;
      8'h76: f_sbox = 8'h27; 8'h77: f_sbox = 8'h52;
      8'h78: f_sbox = 8'h4C; 8'h79: f_sbox = 8'h36;
      8'h7A: f_sbox = 8'h02; 8'h7B: f_sbox = 8'hE7;
      8'h7C: f_sbox = 8'hA0; 8'h7D: f_sbox = 8'hC4;
      8'h7E: f_sbox = 8'hC8; 8'h7F: f_sbox = 8'h9E;
      8'h80: f_sbox = 8'hEA; 8'h81: f_sbox = 8'hBF;
      8'h82: f_sbox = 8'h8A; 8'h83: f_sbox = 8'hD2;
      8'h84: f_sbox = 8'h40; 8'h85: f_sbox = 8'hC7;
      8'h86: f_sbox = 8'h38; 8'h87: f_sbox = 8'hB5;
      8'h88: f_sbox = 8'hA3; 8'h89: f_sbox = 8'hF7;
      8'h8A: f_sbox = 8'hF2; 8'h8B: f_sbox = 8'hCE;
      8'h8C: f_sbox = 8'hF9; 8'h8D: f_sbox = 8'h61;
      8'h8E: f_sbox = 8'h15; 8'h8F: f_sbox = 8'hA1;
      8'h90: f_sbox = 8'hE0; 8'h91: f_sbox = 8'hAE;
      8'h92: f_sbox = 8'h5D; 8'h93: f_sbox = 8'hA4;
      8'h94: f_sbox = 8'h9B; 8'h95: f_sbox = 8'h34;
      8'h96: f_sbox = 8'h1A; 8'h97: f_sbox = 8'h55;
      8'h98: f_sbox = 8'hAD; 8'h99: f_sbox = 8'h93;
      8'h9A: f_sbox = 8'h32; 8'h9B: f_sbox = 8'h30;
      8'h9C: f_sbox = 8'hF5; 8'h9D: f_sbox = 8'h8C;
      8'h9E: f_sbox = 8'hB1; 8'h9F: f_sbox = 8'hE3;
      8'hA0: f_sbox = 8'h1D; 8'hA1: f_sbox = 8'hF6;
      8'hA2: f_sbox = 8'hE2; 8'hA3: f_sbox = 8'h2E;
      8'hA4: f_sbox = 8'h82; 8'hA5: f_sbox = 8'h66;
      8'hA6: f_sbox = 8'hCA; 8'hA7: f_sbox = 8'h60;
      8'hA8: f_sbox = 8'hC0; 8'hA9: f_sbox = 8'h29;
      8'hAA: f_sbox = 8'h23; 8'hAB: f_sbox = 8'hAB;
      8'hAC: f_sbox = 8'h0D; 8'hAD: f_sbox = 8'h53;
      8'hAE: f_sbox = 8'h4E; 8'hAF: f_sbox = 8'h6F;
      8'hB0: f_sbox = 8'hD5; 8'hB1: f_sbox = 8'hDB;
      8'hB2: f_sbox = 8'h37; 8'hB3: f_sbox = 8'h45;
      8'hB4: f_sbox = 8'hDE; 8'hB5: f_sbox = 8'hFD;
      8'hB6: f_sbox = 8'h8E; 8'hB7: f_sbox = 8'h2F;
      8'hB8: f_sbox = 8'h03; 8'hB9: f_sbox = 8'hFF;
      8'hBA: f_sbox = 8'h6A; 8'hBB: f_sbox = 8'h72;
      8'hBC: f_sbox = 8'h6D; 8'hBD: f_sbox = 8'h6C;
      8'hBE: f_sbox = 8'h5B; 8'hBF: f_sbox = 8'h51;
      8'hC0: f_sbox = 8'h8D; 8'hC1: f_sbox = 8'h1B;
      8'hC2: f_sbox = 8'hAF; 8'hC3: f_sbox = 8'h92;
      8'hC4: f_sbox = 8'hBB; 8'hC5: f_sbox = 8'hDD;
      8'hC6: f_sbox = 8'hBC; 8'hC7: f_sbox = 8'h7F;
      8'hC8: f_sbox = 8'h11; 8'hC9: f_sbox = 8'hD9;
      8'hCA: f_sbox = 8'h5C; 8'hCB: f_sbox = 8'h41;
      8'hCC: f_sbox = 8'h1F; 8'hCD: f_sbox = 8'h10;
      8'hCE: f_sbox = 8'h5A; 8'hCF: f_sbox = 8'hD8;
      8'hD0: f_sbox = 8'h0A; 8'hD1: f_sbox = 8'hC1;
      8'hD2: f_sbox = 8'h31; 8'hD3: f_sbox = 8'h88;
      8'hD4: f_sbox = 8'hA5; 8'hD5: f_sbox = 8'hCD;
      8'hD6: f_sbox = 8'h7B; 8'hD7: f_sbox = 8'hBD;
      8'hD8: f_sbox = 8'h2D; 8'hD9: f_sbox = 8'h74;
      8'hDA: f_sbox = 8'hD0; 8'hDB: f_sbox = 8'h12;
      8'hDC: f_sbox = 8'hB8; 8'hDD: f_sbox = 8'hE5;
      8'hDE: f_sbox = 8'hB4; 8'hDF: f_sbox = 8'hB0;
      8'hE0: f_sbox = 8'h89; 8'hE1: f_sbox = 8'h69;
      8'hE2: f_sbox = 8'h97; 8'hE3: f_sbox = 8'h4A;
      8'hE4: f_sbox = 8'h0C; 8'hE5: f_sbox = 8'h96;
      8'hE6: f_sbox = 8'h77; 8'hE7: f_sbox = 8'h7E;
      8'hE8: f_sbox = 8'h65; 8'hE9: f_sbox = 8'hB9;
      8'hEA: f_sbox = 8'hF1; 8'hEB: f_sbox = 8'h09;
      8'hEC: f_sbox = 8'hC5; 8'hED: f_sbox = 8'h6E;
      8'hEE: f_sbox = 8'hC6; 8'hEF: f_sbox = 8'h84;
      8'hF0: f_sbox = 8'h18; 8'hF1: f_sbox = 8'hF0;
      8'hF2: f_sbox = 8'h7D; 8'hF3: f_sbox = 8'hEC;
      8'hF4: f_sbox = 8'h3A; 8'hF5: f_sbox = 8'hDC;
      8'hF6: f_sbox = 8'h4D; 8'hF7: f_sbox = 8'h20;
      8'hF8: f_sbox = 8'h79; 8'hF9: f_sbox = 8'hEE;
      8'hFA: f_sbox = 8'h5F; 8'hFB: f_sbox = 8'h3E;
      8'hFC: f_sbox = 8'hD7; 8'hFD: f_sbox = 8'hCB;
      8'hFE: f_sbox = 8'h39; 8'hFF: f_sbox = 8'h48;
      // Unreachable: every 8-bit value is listed above. Kept for tool lints.
      default: f_sbox = 8'h00;
    endcase
  endfunction

  function automatic word_t f_rotl (input word_t x, input int unsigned n);
    if (n == 0) f_rotl = x;
    else        f_rotl = (x << n) | (x >> (32 - n));
  endfunction

  function automatic word_t f_tau (input word_t x);
    f_tau = {f_sbox(x[31:24]), f_sbox(x[23:16]),
             f_sbox(x[15: 8]), f_sbox(x[ 7: 0])};
  endfunction

  // Round-function mixer: T(x) = tau(x) ^ rotl(tau,2) ^ rotl(tau,10)
  //                              ^ rotl(tau,18) ^ rotl(tau,24).
  function automatic word_t f_t (input word_t x);
    word_t t;
    t = f_tau(x);
    f_t = t ^ f_rotl(t, 2) ^ f_rotl(t, 10) ^ f_rotl(t, 18) ^ f_rotl(t, 24);
  endfunction

  // Key-schedule mixer: T'(x) = tau(x) ^ rotl(tau,13) ^ rotl(tau,23).
  function automatic word_t f_t_key (input word_t x);
    word_t t;
    t = f_tau(x);
    f_t_key = t ^ f_rotl(t, 13) ^ f_rotl(t, 23);
  endfunction

endpackage : sm4_pkg

`default_nettype wire
