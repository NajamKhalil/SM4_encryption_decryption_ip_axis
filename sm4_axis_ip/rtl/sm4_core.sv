////////////////////////////////////////////////////////////////////////////////
//
// Project Name        : SM4 AXI4-Stream IP
// Module Name         : sm4_core
// Creation Date       : 2026-11-25
// Author              : najam
//
// Function            :
//   Iterative SM4 block engine. One unbalanced Feistel round is evaluated
//   per clock: X[i+4] = X[i] ^ T(X[i+1] ^ X[i+2] ^ X[i+3] ^ rk[i]).
//   Decryption reuses the same round keys in reverse order. The final
//   reverse transform R is applied when the result word is assembled.
//
// HOW TO INITIALISE AND USE:
//   Wait for rk_valid_i, pulse start_i with block_i and mode_i stable.
//   done_o pulses one cycle after the 32nd round; result_o is then stable.
//   busy_o stays high from start until the result has been delivered.
//
////////////////////////////////////////////////////////////////////////////////

`default_nettype none

module sm4_core
(
  input  logic                 clk,
  input  logic                 arst_n,

  input  logic                 start_i,
  input  logic                 mode_i,       // 0 = encrypt, 1 = decrypt
  input  logic [127:0]         block_i,
  input  logic                 rk_valid_i,
  input  logic [1023:0]        rk_i,

  output logic                 busy_o,
  output logic                 done_o,
  output logic [127:0]         result_o
);
  import sm4_pkg::*;

  // ==========================================================================
  // 1. FSM AND STATE WORDS
  // ==========================================================================

  typedef enum logic [1:0] {
    ST_CORE_IDLE = 2'd0,
    ST_CORE_RUN  = 2'd1,
    ST_CORE_DONE = 2'd2
  } e_core_state;

  e_core_state state_q;
  logic [4:0]  round_q;
  logic        mode_q;
  word_t       x0_q, x1_q, x2_q, x3_q;

  // ==========================================================================
  // 2. ROUND COMBINATIONAL LOGIC
  //    The S-box lookups and the five rotations are the only logic between
  //    registers, so the critical path is one T() evaluation per cycle.
  // ==========================================================================

  word_t       mixer_c;
  word_t       xnew_c;
  logic [4:0]  rk_index_c;

  assign rk_index_c = mode_q ? (5'd31 - round_q) : round_q;
  assign mixer_c    = rk_i[rk_index_c*32 +: 32] ^ x1_q ^ x2_q ^ x3_q;
  assign xnew_c     = x0_q ^ f_t(mixer_c);

  assign busy_o = (state_q != ST_CORE_IDLE);

  // ==========================================================================
  // 3. 32-ROUND ITERATION AND FINAL REVERSE TRANSFORM
  // ==========================================================================

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      state_q  <= ST_CORE_IDLE;
      round_q  <= 5'd0;
      mode_q   <= 1'b0;
      x0_q     <= 32'h0;
      x1_q     <= 32'h0;
      x2_q     <= 32'h0;
      x3_q     <= 32'h0;
      result_o <= 128'h0;
      done_o   <= 1'b0;
    end
    else begin
      done_o <= 1'b0;
      case (state_q)
        ST_CORE_IDLE: begin
          if (start_i && rk_valid_i) begin
            x0_q    <= block_i[127:96];
            x1_q    <= block_i[ 95:64];
            x2_q    <= block_i[ 63:32];
            x3_q    <= block_i[ 31: 0];
            mode_q  <= mode_i;
            round_q <= 5'd0;
            state_q <= ST_CORE_RUN;
          end
        end

        ST_CORE_RUN: begin
          // Before round i the registers hold (X_i, X_i+1, X_i+2, X_i+3).
          x0_q    <= x1_q;
          x1_q    <= x2_q;
          x2_q    <= x3_q;
          x3_q    <= xnew_c;
          round_q <= round_q + 5'd1;
          if (round_q == 5'd31) begin
            // R transform: (X35, X34, X33, X32) in big-endian word order.
            result_o <= {xnew_c, x3_q, x2_q, x1_q};
            done_o   <= 1'b1;
            state_q  <= ST_CORE_DONE;
          end
        end

        ST_CORE_DONE: begin
          state_q <= ST_CORE_IDLE;
        end

        default: begin
          state_q <= ST_CORE_IDLE;
        end
      endcase
    end
  end

  // ==========================================================================
  // 4. SIMULATION-ONLY CHECKS
  // ==========================================================================

`ifdef RTL_SIM
  always_ff @(posedge clk) begin
    if (start_i && !rk_valid_i) begin
      $error("sm4_core: start_i asserted without valid round keys");
    end
    if (state_q == ST_CORE_RUN && $isunknown(xnew_c)) begin
      $error("sm4_core: X propagation in round %0d", round_q);
    end
  end
`endif // RTL_SIM

endmodule : sm4_core

`default_nettype wire
