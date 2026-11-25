////////////////////////////////////////////////////////////////////////////////
//
// Project Name        : SM4 AXI4-Stream IP
// Module Name         : sm4_key_schedule
// Creation Date       : 2026-11-25
// Author              : najam
//
// Function            :
//   Generates the 32 SM4 round keys from a 128-bit key. One key word is
//   produced per clock: K[i] ^= T'(K[i+1] ^ K[i+2] ^ K[i+3] ^ CK[i]).
//   Round keys are exposed as a flat 1024-bit vector; word i occupies
//   bits [32*i +: 32].
//
// HOW TO INITIALISE AND USE:
//   Pulse key_valid_i with key_i stable while key_ready_o is high. After 32
//   cycles rk_valid_o rises and the round-key vector is stable until another
//   key is accepted. The caller must not change the key while rk_valid_o is
//   low and must not accept a new key while a block is being processed.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
`default_nettype none

module sm4_key_schedule
(
  input  logic                 clk,
  input  logic                 arst_n,

  input  logic                 key_valid_i,
  input  logic [127:0]         key_i,
  output logic                 key_ready_o,

  output logic [1023:0]        rk_o,
  output logic                 rk_valid_o
);
  import sm4_pkg::*;

  // ==========================================================================
  // 1. STATE
  // ==========================================================================

  typedef enum logic [1:0] {
    ST_KS_IDLE = 2'd0,
    ST_KS_SEED = 2'd1,
    ST_KS_GEN  = 2'd2,
    ST_KS_DONE = 2'd3
  } e_ks_state;

  e_ks_state    state_q;
  logic [4:0]   round_q;
  logic [31:0]  k0_q, k1_q, k2_q, k3_q;

  // ==========================================================================
  // 2. ONE ROUND OF T' PER CYCLE
  //    The XOR operands are the CURRENT K words, then only K[round % 4]
  //    is updated - this is the rolling update in the SM4 key schedule.
  // ==========================================================================

  logic [31:0] mix_c;

  // Written as a continuous assignment rather than an always_comb case so
  // that every supported simulator elaborates the byte selects identically.
  assign mix_c =
    (round_q[1:0] == 2'd0) ? f_t_key(k1_q ^ k2_q ^ k3_q ^ f_ck(round_q)) :
    (round_q[1:0] == 2'd1) ? f_t_key(k2_q ^ k3_q ^ k0_q ^ f_ck(round_q)) :
    (round_q[1:0] == 2'd2) ? f_t_key(k3_q ^ k0_q ^ k1_q ^ f_ck(round_q)) :
                             f_t_key(k0_q ^ k1_q ^ k2_q ^ f_ck(round_q));

  // ready is a registered-state predicate: it never depends on a downstream
  // ready, so it cannot form a valid->ready combinational loop.
  assign key_ready_o = (state_q == ST_KS_IDLE) || (state_q == ST_KS_DONE);

  // ==========================================================================
  // 3. SEQUENTIAL KEY EXPANSION
  // ==========================================================================

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      state_q    <= ST_KS_IDLE;
      round_q    <= 5'd0;
      k0_q       <= 32'h0;
      k1_q       <= 32'h0;
      k2_q       <= 32'h0;
      k3_q       <= 32'h0;
      rk_o       <= 1024'h0;
      rk_valid_o <= 1'b0;
    end
    else begin
      case (state_q)
        ST_KS_IDLE, ST_KS_DONE: begin
          if (key_valid_i && key_ready_o) begin
            // MK[i] XOR FK[i]; big-endian word order, as in the standard.
            k0_q       <= key_i[127:96] ^ f_fk(0);
            k1_q       <= key_i[ 95:64] ^ f_fk(1);
            k2_q       <= key_i[ 63:32] ^ f_fk(2);
            k3_q       <= key_i[ 31: 0] ^ f_fk(3);
            round_q    <= 5'd0;
            rk_valid_o <= 1'b0;
            state_q    <= ST_KS_SEED;
          end
        end

        ST_KS_SEED: begin
          // Seed cycle is separate so the first T' sees the seeded K words.
          state_q <= ST_KS_GEN;
        end

        ST_KS_GEN: begin
          case (round_q[1:0])
            2'd0: begin
              k0_q                    <= k0_q ^ mix_c;
              rk_o[round_q*32 +: 32]  <= k0_q ^ mix_c;
            end
            2'd1: begin
              k1_q                    <= k1_q ^ mix_c;
              rk_o[round_q*32 +: 32]  <= k1_q ^ mix_c;
            end
            2'd2: begin
              k2_q                    <= k2_q ^ mix_c;
              rk_o[round_q*32 +: 32]  <= k2_q ^ mix_c;
            end
            default: begin
              k3_q                    <= k3_q ^ mix_c;
              rk_o[round_q*32 +: 32]  <= k3_q ^ mix_c;
            end
          endcase
          round_q <= round_q + 5'd1;
          if (round_q == 5'd31) begin
            state_q    <= ST_KS_DONE;
            rk_valid_o <= 1'b1;
          end
        end

        default: begin
          state_q <= ST_KS_IDLE;
        end
      endcase
    end
  end

  // ==========================================================================
  // 4. ELABORATION CHECKS
  // ==========================================================================

  generate
    if (1024 != 32*32) begin : g_chk_rk_width
      $fatal(1, "sm4_key_schedule: round-key vector width is inconsistent");
    end
  endgenerate

  // ==========================================================================
  // 5. SIMULATION-ONLY CHECKS
  // ==========================================================================

`ifdef RTL_SIM
  always @(posedge clk) begin
    if (key_valid_i && key_ready_o && $isunknown(key_i)) begin
      $error("sm4_key_schedule: X on key_i while handshake fires");
    end
  end
`endif // RTL_SIM

endmodule : sm4_key_schedule

`default_nettype wire
