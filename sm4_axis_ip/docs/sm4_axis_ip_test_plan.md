# SM4 AXI4-Stream IP - Test Plan

| Field | Value |
|-------|-------|
| Project | SM4 AXI4-Stream IP |
| Document type | Test Plan |
| Author | najam |
| Date | 2026-11-25 |
| Status | DONE |

## 1. Objective

Prove that the AXI4-Stream wrapper and the SM4 engine agree with an
independent behavioural reference model, and that the published known-answer
vectors are reproduced exactly. All checks run in one self-checking
SystemVerilog bench.

## 2. Environment

The bench is `sim/tb_sm4_axis_ip.sv`. It is compiled with Icarus Verilog
12.0 using `-g2012 -D RTL_SIM` and the bottom-to-top file list in
`sim/f_list.f`. `sim/run.sh tb_sm4_axis_ip` compiles, runs and writes
`sim/sim.log`. The bench uses a 10 ns clock and drives and samples on
`negedge clk` to avoid races with the DUT registers.

## 3. Reference model

The golden model in the bench has its own case-table S-box, its own FK and CK
constants and its own loop-based key expansion and cipher. It does not import
`sm4_pkg` and does not call any DUT function. Expected results are queued at
the moment a beat is sent and compared with the master interface by a separate
monitor process.

## 4. Planned cases

| ID | What it proves | Stimulus | Status |
|----|----------------|----------|--------|
| TC-01 | Published encrypt vector | Key and plaintext `0123456789ABCDEFFEDCBA9876543210`, ciphertext `681EDF34D206965E86B3E94F536E4246` | PASS |
| TC-02 | Published decrypt vector | Same key, ciphertext from TC-01, expect the original plaintext | PASS |
| TC-03 | Random encrypt traffic with slave stalls | 16 random blocks with 0 to 3 idle beats before each offer | PASS |
| TC-04 | Random decrypt traffic with master backpressure | 16 random blocks while `TREADY` is pseudo-randomly deasserted | PASS |
| TC-05 | Key reload and sideband replay | New key, `TID=F`, `TDEST=7`, `TUSER=3`, three stall beats | PASS |
| TC-06 | Second key reload | Different key on the same plaintext, distinct sideband values | PASS |
| TC-07 | Input skid buffer occupancy | Back-to-back offers while the engine is busy | PASS |
| TC-08 | Output stability under backpressure | `TVALID` held with stable payload until accepted | PASS |
| TC-09 | Reset and recovery | Reset while a beat is offered, reload key, recheck known answer | PASS |
| TC-10 | Final scoreboard | Match count equals beat count and mismatch count is zero | PASS |

## 5. Protocol checks

With `RTL_SIM` defined, the wrapper flags unknown data on a completed
handshake, any `TKEEP` or `TSTRB` that is not all ones, any beat without
`TLAST`, and an attempt to overwrite an undrained result register. The key
schedule flags unknown key bits on acceptance; the core flags a start without
valid round keys and X propagation during a round.

## 6. Exit criteria

The run is a pass only when the monitor reports `RESULT = PASS`, every
expected beat matches data and sidebands, and the mismatch counter is zero.
A 500000 ns hang guard reports `RESULT = FAIL (timeout)` instead of allowing
a stalled handshake to be counted as success.
