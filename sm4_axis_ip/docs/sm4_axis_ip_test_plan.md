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
vectors are reproduced exactly. Directed cases, a repeatable multi-seed
regression and a mutation campaign are all run from the same self-checking
SystemVerilog bench.

## 2. Environment

The bench is `sim/tb_sm4_axis_ip.sv`. It is compiled with Icarus Verilog
12.0 using `-g2012 -D RTL_SIM` and the bottom-to-top file list in
`sim/f_list.f`. `sim/run.sh tb_sm4_axis_ip` compiles, runs one directed
scenario and writes `sim/sim.log`. `sim/run_regression.sh` compiles once and
runs 24 replays with `+SEED=<n> +BLOCKS=<n>`, writing `sim/regression.log`.
The bench uses a 10 ns clock and drives and samples on `negedge clk` to avoid
races with the DUT registers.

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
| TC-03 | Random encrypt traffic with slave stalls | A seed-derived random key and 32 random blocks, each with 0 to 3 idle beats | PASS |
| TC-04 | Random decrypt traffic with master backpressure | A seed-derived random key and 32 random blocks while `TREADY` is pseudo-randomly deasserted | PASS |
| TC-05 | Key reload and sideband replay | New key, `TID=F`, `TDEST=7`, `TUSER=3`, three stall beats | PASS |
| TC-06 | Second key reload | Different key on the same plaintext, distinct sideband values | PASS |
| TC-07 | Input skid buffer occupancy | Back-to-back offers while the engine is busy | PASS |
| TC-08 | Output stability under backpressure | `TVALID` held with stable payload until accepted | PASS |
| TC-09 | Reset and recovery | Reset while a beat is offered, reload key, recheck known answer | PASS |
| TC-10 | Final scoreboard | Match count equals beat count and mismatch count is zero | PASS |

## 5. Testing the tests: mutation testing

A testbench that has never failed proves nothing. **Twelve deliberate bugs**
were injected into temporary copies of the RTL, one at a time, and the full
multi-seed regression was re-run against each, against the final revision of
the RTL and testbench so the result describes the code that ships. The first
failure printed by each run is recorded in the verification report.

### 5.1 Caught - 12 of 12

| ID | Status | Mutation and first failure |
|----|--------|----------------------------|
| M01 | KILLED | S-box byte 00 maps to D7 instead of D6; mismatched master beat |
| M02 | KILLED | `FK[0]` corrupted by one LSB; mismatched master beat |
| M03 | KILLED | `CK[0]` corrupted by one LSB; mismatched master beat |
| M04 | KILLED | Round mixer rotates tau by 3 instead of 2; mismatched master beat |
| M05 | KILLED | Key mixer rotates tau by 14 instead of 13; mismatched master beat |
| M06 | KILLED | Decrypt consumes round keys in forward order; mismatched master beat |
| M07 | KILLED | Final reverse transform emits words in the wrong order |
| M08 | KILLED | Engine stops after 31 rounds instead of 32 |
| M09 | KILLED | Output `TLAST` forced low; monitor rejects the beat |
| M10 | KILLED | Output `TKEEP` forced to all zeros; monitor rejects the beat |
| M11 | KILLED | Output `TID` no longer replays the captured sideband |
| M12 | KILLED | Slave `TREADY` ignores skid-buffer occupancy; handshake corrupts traffic |

### 5.2 Survivors - 0 of 12

No mutants survived, so no equivalence arguments are required.

## 6. Protocol checks

With `RTL_SIM` defined, the wrapper flags unknown data on a completed
handshake, any `TKEEP` or `TSTRB` that is not all ones, any beat without
`TLAST`, and an attempt to overwrite an undrained result register. The key
schedule flags unknown key bits on acceptance; the core flags a start without
valid round keys and X propagation during a round.

## 7. Exit criteria

A single run is a pass only when the monitor reports `RESULT = PASS`, every
expected beat matches data and sidebands, and the mismatch counter is zero.
The regression is a pass only when every seeded run passes. A 500000 ns hang
guard reports `RESULT = FAIL (timeout)` instead of allowing a stalled
handshake to be counted as success.
