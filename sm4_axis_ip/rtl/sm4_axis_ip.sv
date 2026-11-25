////////////////////////////////////////////////////////////////////////////////
//
// Project Name        : SM4 AXI4-Stream IP
// Module Name         : sm4_axis_ip
// Creation Date       : 2026-11-25
// Author              : najam
//
// Function            :
//   AXI4-Stream wrapper around the SM4 block engine. One input beat is one
//   128-bit block; one output beat is the transformed block with TLAST set.
//   Input ready is registered through a two-deep elastic buffer, so no
//   valid->ready or ready->ready combinational path crosses the block.
//   Output valid is registered and never withdrawn before TREADY.
//
// HOW TO INITIALISE AND USE:
//   Load a key with key_valid_i/key_ready_o while no block is running.
//   Drive mode_i (0 encrypt, 1 decrypt) and supply blocks on the slave
//   interface with TKEEP/TSTRB all ones and TLAST asserted on every beat.
//   TID, TDEST and TUSER are passed through to the matching output beat.
//   An incomplete key schedule holds input ready until round keys are valid.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
`default_nettype none

module sm4_axis_ip
#(
  parameter int TID_WIDTH   = 8,
  parameter int TDEST_WIDTH = 8,
  parameter int TUSER_WIDTH = 8
)
(
  input  logic                       axi_st_clk,
  input  logic                       axi_st_areset_n,

  // AXI4-Stream slave: one 128-bit block per beat.
  input  logic                       s_axis_tvalid_i,
  output logic                       s_axis_tready_o,
  input  logic [127:0]               s_axis_tdata_i,
  input  logic [ 15:0]               s_axis_tstrb_i,
  input  logic [ 15:0]               s_axis_tkeep_i,
  input  logic                       s_axis_tlast_i,
  input  logic [TID_WIDTH-1:0]       s_axis_tid_i,
  input  logic [TDEST_WIDTH-1:0]     s_axis_tdest_i,
  input  logic [TUSER_WIDTH-1:0]     s_axis_tuser_i,

  // AXI4-Stream master: one transformed block per beat.
  output logic                       m_axis_tvalid_o,
  input  logic                       m_axis_tready_i,
  output logic [127:0]               m_axis_tdata_o,
  output logic [ 15:0]               m_axis_tstrb_o,
  output logic [ 15:0]               m_axis_tkeep_o,
  output logic                       m_axis_tlast_o,
  output logic [TID_WIDTH-1:0]       m_axis_tid_o,
  output logic [TDEST_WIDTH-1:0]     m_axis_tdest_o,
  output logic [TUSER_WIDTH-1:0]     m_axis_tuser_o,

  // Key and direction sideband.
  input  logic [127:0]               key_i,
  input  logic                       key_valid_i,
  output logic                       key_ready_o,
  input  logic                       mode_i        // 0 = encrypt, 1 = decrypt
);

  localparam int TKEEP_WIDTH = 16;
  localparam int IN_DEPTH    = 2;

  // ==========================================================================
  // 1. INPUT ELASTIC BUFFER - REGISTERED READY, NO WITHDRAWN OFFER
  // ==========================================================================

  logic [127:0]              in_data_q   [0:IN_DEPTH-1];
  logic [TKEEP_WIDTH-1:0]    in_keep_q   [0:IN_DEPTH-1];
  logic [TKEEP_WIDTH-1:0]    in_strb_q   [0:IN_DEPTH-1];
  logic                      in_last_q   [0:IN_DEPTH-1];
  logic [TID_WIDTH-1:0]      in_id_q     [0:IN_DEPTH-1];
  logic [TDEST_WIDTH-1:0]    in_dest_q   [0:IN_DEPTH-1];
  logic [TUSER_WIDTH-1:0]    in_user_q   [0:IN_DEPTH-1];
  logic [0:0]                in_wr_q;
  logic [0:0]                in_rd_q;
  logic [1:0]                in_count_q;
  logic [1:0]                in_count_c;

  logic                      push_s;
  logic                      core_start_s;
  logic [127:0]              core_block_s;

  // Ready depends only on the registered occupancy: it is stable between
  // clocks and cannot be pulled down by downstream backpressure.
  assign s_axis_tready_o = (in_count_q < 2'd2);
  assign push_s          = s_axis_tvalid_i && s_axis_tready_o;

  // The core is the consumer; it starts only when it has keys and somewhere
  // to put the result. That bounds the design to one in-flight result.
  assign core_start_s = !u_core_busy_o && ks_rk_valid_o &&
                        (in_count_q != 2'd0) && !result_valid_q;
  assign core_block_s = in_data_q[in_rd_q];

  always_comb begin
    in_count_c = in_count_q;
    if (push_s)        in_count_c = in_count_c + 2'd1;
    if (core_start_s)  in_count_c = in_count_c - 2'd1;
  end

  always_ff @(posedge axi_st_clk or negedge axi_st_areset_n) begin
    if (!axi_st_areset_n) begin
      in_wr_q    <= 1'b0;
      in_rd_q    <= 1'b0;
      in_count_q <= 2'd0;
      for (int i = 0; i < IN_DEPTH; i++) begin
        in_data_q[i] <= 128'h0;
        in_keep_q[i] <= {TKEEP_WIDTH{1'b0}};
        in_strb_q[i] <= {TKEEP_WIDTH{1'b0}};
        in_last_q[i] <= 1'b0;
        in_id_q[i]   <= '0;
        in_dest_q[i] <= '0;
        in_user_q[i] <= '0;
      end
    end
    else begin
      in_count_q <= in_count_c;
      if (push_s) begin
        in_data_q[in_wr_q] <= s_axis_tdata_i;
        in_keep_q[in_wr_q] <= s_axis_tkeep_i;
        in_strb_q[in_wr_q] <= s_axis_tstrb_i;
        in_last_q[in_wr_q] <= s_axis_tlast_i;
        in_id_q[in_wr_q]   <= s_axis_tid_i;
        in_dest_q[in_wr_q] <= s_axis_tdest_i;
        in_user_q[in_wr_q] <= s_axis_tuser_i;
        in_wr_q            <= in_wr_q + 1'b1;
      end
      if (core_start_s) begin
        in_rd_q <= in_rd_q + 1'b1;
      end
    end
  end

  // ==========================================================================
  // 2. KEY SCHEDULE AND BLOCK ENGINE
  // ==========================================================================

  logic        ks_key_ready_o;
  logic        ks_rk_valid_o;
  logic [1023:0] ks_rk_o;
  logic        u_core_busy_o;
  logic        u_core_done_o;
  logic [127:0] u_core_result_o;

  assign key_ready_o = ks_key_ready_o && !u_core_busy_o;

  sm4_key_schedule u_key_schedule (
    .clk         (axi_st_clk     ),
    .arst_n      (axi_st_areset_n),
    .key_valid_i (key_valid_i    ),
    .key_i       (key_i          ),
    .key_ready_o (ks_key_ready_o ),
    .rk_o        (ks_rk_o        ),
    .rk_valid_o  (ks_rk_valid_o  )
  );

  sm4_core u_core (
    .clk        (axi_st_clk     ),
    .arst_n     (axi_st_areset_n),
    .start_i    (core_start_s   ),
    .mode_i     (mode_i         ),
    .block_i    (core_block_s   ),
    .rk_valid_i (ks_rk_valid_o  ),
    .rk_i       (ks_rk_o        ),
    .busy_o     (u_core_busy_o  ),
    .done_o     (u_core_done_o  ),
    .result_o   (u_core_result_o)
  );

  // ==========================================================================
  // 3. OUTPUT REGISTERED READY/VALID STAGE
  //    TVALID/TDATA/TID/TDEST/TUSER stay stable until TREADY is asserted.
  // ==========================================================================

  logic [127:0]           result_q;
  logic                   result_valid_q;
  logic [TID_WIDTH-1:0]   result_id_q;
  logic [TDEST_WIDTH-1:0] result_dest_q;
  logic [TUSER_WIDTH-1:0] result_user_q;
  logic [TID_WIDTH-1:0]   active_id_q;
  logic [TDEST_WIDTH-1:0] active_dest_q;
  logic [TUSER_WIDTH-1:0] active_user_q;

  always_ff @(posedge axi_st_clk or negedge axi_st_areset_n) begin
    if (!axi_st_areset_n) begin
      result_q       <= 128'h0;
      result_valid_q <= 1'b0;
      result_id_q    <= '0;
      result_dest_q  <= '0;
      result_user_q  <= '0;
      active_id_q    <= {TID_WIDTH{1'b0}};
      active_dest_q  <= {TDEST_WIDTH{1'b0}};
      active_user_q  <= {TUSER_WIDTH{1'b0}};
    end
    else begin
      if (core_start_s) begin
        active_id_q    <= in_id_q[in_rd_q];
        active_dest_q  <= in_dest_q[in_rd_q];
        active_user_q  <= in_user_q[in_rd_q];
      end
      if (u_core_done_o) begin
        result_q       <= u_core_result_o;
        result_valid_q <= 1'b1;
        result_id_q    <= active_id_q;
        result_dest_q  <= active_dest_q;
        result_user_q  <= active_user_q;
      end
      else if (m_axis_tvalid_o && m_axis_tready_i) begin
        result_valid_q <= 1'b0;
      end
    end
  end

  assign m_axis_tvalid_o = result_valid_q;
  assign m_axis_tdata_o  = result_q;
  assign m_axis_tstrb_o  = {TKEEP_WIDTH{1'b1}};
  assign m_axis_tkeep_o  = {TKEEP_WIDTH{1'b1}};
  assign m_axis_tlast_o  = 1'b1;
  assign m_axis_tid_o    = result_id_q;
  assign m_axis_tdest_o  = result_dest_q;
  assign m_axis_tuser_o  = result_user_q;

  // ==========================================================================
  // 4. ELABORATION CHECKS
  // ==========================================================================

  generate
    if (TID_WIDTH < 1) begin : g_chk_tid
      $fatal(1, "sm4_axis_ip: TID_WIDTH must be >= 1, got %0d", TID_WIDTH);
    end
    if (TDEST_WIDTH < 1) begin : g_chk_tdest
      $fatal(1, "sm4_axis_ip: TDEST_WIDTH must be >= 1, got %0d", TDEST_WIDTH);
    end
    if (TUSER_WIDTH < 1) begin : g_chk_tuser
      $fatal(1, "sm4_axis_ip: TUSER_WIDTH must be >= 1, got %0d", TUSER_WIDTH);
    end
  endgenerate

  // ==========================================================================
  // 5. SIMULATION-ONLY PROTOCOL CHECKS
  // ==========================================================================

`ifdef RTL_SIM
  always @(posedge axi_st_clk) begin
    if (push_s) begin
      if ($isunknown(s_axis_tdata_i) || $isunknown(s_axis_tkeep_i) ||
          $isunknown(s_axis_tstrb_i)) begin
        $error("sm4_axis_ip: X on slave beat while handshake fires");
      end
      if (s_axis_tkeep_i != {TKEEP_WIDTH{1'b1}}) begin
        $error("sm4_axis_ip: partial TKEEP is not supported (got %h)",
               s_axis_tkeep_i);
      end
      if (s_axis_tstrb_i != {TKEEP_WIDTH{1'b1}}) begin
        $error("sm4_axis_ip: partial TSTRB is not supported (got %h)",
               s_axis_tstrb_i);
      end
      if (!s_axis_tlast_i) begin
        $error("sm4_axis_ip: TLAST must be asserted on every block beat");
      end
    end
    if (m_axis_tvalid_o && m_axis_tready_i && $isunknown(m_axis_tdata_o)) begin
      $error("sm4_axis_ip: X on master beat while handshake fires");
    end
    if (u_core_done_o && result_valid_q) begin
      $error("sm4_axis_ip: result buffer overwritten before it was drained");
    end
  end
`endif // RTL_SIM

endmodule : sm4_axis_ip

`default_nettype wire
