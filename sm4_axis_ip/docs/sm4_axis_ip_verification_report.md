# SM4 AXI4-Stream IP - Verification Report

| Field | Value |
|-------|-------|
| Project | SM4 AXI4-Stream IP |
| Document type | Verification Report |
| Author | najam |
| Date | 2026-11-25 |
| Status | DONE |

## 1. Summary

All ten planned cases were exercised in a single self-checking simulation.
The DUT produced 37 master beats and the scoreboard recorded 37 matches and
zero mismatches. The multi-seed regression then ran 24 independent replays
with 32 encrypt and 32 decrypt blocks per replay, giving 1656 checked beats
with zero failures. A 12-mutant campaign was run to prove that the suite can
fail when the RTL is wrong.

## 2. Simulation and regression evidence

`sim/run.sh tb_sm4_axis_ip` writes the directed report to `sim/sim.log`:

```
MATCH      COUNTER     = 37
MISMATCH   COUNTER     = 0
BEATS      CHECKED     = 37
RESULT = PASS (37 matches, 0 mismatches)
```

`sim/run_regression.sh` writes the campaign report to `sim/regression.log`:

```
TOTAL BEATS = 1656
FAILURES    = 0
RESULT = PASS (multi-seed: 24/24 runs, 1656 beats, 0 failures)
```

Every replay used a different `+SEED` value and a seed-derived random key.
Master `TREADY` and slave-side idle insertion were also derived from that
seed, so any run can be reproduced exactly. The published vector with key and
plaintext `0123456789ABCDEFFEDCBA9876543210` and expected ciphertext
`681EDF34D206965E86B3E94F536E4246` was checked in every replay, not only in
the directed run.

### 2.1 Case results

| ID | Result | Evidence |
|----|--------|----------|
| TC-01 | PASS | Known-answer ciphertext compared with the published constant |
| TC-02 | PASS | Published ciphertext decrypts to the original plaintext |
| TC-03 | PASS | Random encrypt blocks with staggered slave offers |
| TC-04 | PASS | Random decrypt blocks with pseudo-random master `TREADY` |
| TC-05 | PASS | Key reload with `TID`, `TDEST` and `TUSER` replay |
| TC-06 | PASS | Second key reload changes the cipher output |
| TC-07 | PASS | Skid buffer accepts offers while the engine is busy |
| TC-08 | PASS | Registered output data stays stable while `TREADY` is low |
| TC-09 | PASS | Recovery after reset with a fresh key and known answer |
| TC-10 | PASS | Final match counter equals beat counter with zero mismatches |

## 3. Testing the tests: mutation results

A testbench that has never failed proves nothing. Twelve deliberate bugs were
injected into temporary copies of the RTL, one at a time, and the full
multi-seed regression was re-run against each. Every mutation ran against the
final revision of the RTL and testbench, so these numbers describe the code
that ships. The parenthesised figure is that run's total mismatch count.

### 3.1 Caught - 12 of 12

| ID | Status | Mutation | First failure reported |
|----|--------|----------|------------------------|
| M01 | KILLED | S-box byte 00 maps to D7 instead of D6 | `ERROR: bad master beat data=9476ccf56fbee415d1e7c8b2a99c05d2 id=1 dest=2 user=1 last=1` (72 mismatches) |
| M02 | KILLED | FK[0] corrupted by one LSB | `ERROR: bad master beat data=3cb16f9ebc75aa1e2dbb220bdb404000 id=1 dest=2 user=1 last=1` (72) |
| M03 | KILLED | CK[0] corrupted by one LSB | `ERROR: bad master beat data=a4e392a0c4210f3d5d17e71a8b796a4d id=1 dest=2 user=1 last=1` (72) |
| M04 | KILLED | Round mixer rotates tau by 3 instead of 2 | `ERROR: bad master beat data=b09a210f19e1f4220ab1206ef3c87a93 id=1 dest=2 user=1 last=1` (72) |
| M05 | KILLED | Key mixer rotates tau by 14 instead of 13 | `ERROR: bad master beat data=5527ee92acbf823d00676b95c4a2f9a8 id=1 dest=2 user=1 last=1` (72) |
| M06 | KILLED | Decrypt consumes round keys in forward order | `ERROR: bad master beat data=f324184f3c8892b72bdc9d7c612919de id=2 dest=3 user=2 last=1` (69) |
| M07 | KILLED | Final reverse transform emits words in the wrong order | `ERROR: bad master beat data=d206965e86b3e94f536e4246681edf34 id=1 dest=2 user=1 last=1` (72) |
| M08 | KILLED | Engine stops after 31 rounds instead of 32 | `ERROR: bad master beat data=d206965e86b3e94f536e42467b938f4c id=1 dest=2 user=1 last=1` (72) |
| M09 | KILLED | Output TLAST forced low | `ERROR: bad master beat data=681edf34d206965e86b3e94f536e4246 id=1 dest=2 user=1 last=0` (69) |
| M10 | KILLED | Output TKEEP forced to all zeros | `ERROR: bad master beat data=681edf34d206965e86b3e94f536e4246 id=1 dest=2 user=1 last=1` (69) |
| M11 | KILLED | Output TID no longer replays the captured sideband | `ERROR: bad master beat data=681edf34d206965e86b3e94f536e4246 id=0 dest=2 user=1 last=1` (69) |
| M12 | KILLED | Slave ready ignores skid-buffer occupancy | `ERROR: bad master beat data=a24bea8e7cea78b0382f392d6b32b252 id=d dest=5 user=1 last=1` (3) |

The detectors are spread across every layer of the bench: the published
constant catches M01 to M05 and M08, the independent model catches the
remaining algorithm faults, and the interface monitor catches M09 to M12.

### 3.2 Survivors - 0 of 12

No mutants survived, so no equivalence arguments are required. The complete
machine-readable record is in `sim/mutation.rpt` and `sim/mutation.log`.

## 4. Algorithm cross-check

The 256 S-box entries in the package were compared byte for byte with the
reference table published in the OpenSSL SM4 implementation. All 256 values
are identical. The known-answer test then confirms the surrounding key
schedule, rotations and final reverse transform.

## 5. Lint, synthesis and CDC evidence

`lint/run_lint.sh` combines `iverilog -Wall` elaboration with a Yosys
`check -assert` pass and records `0 errors` in `lint/lint.log`.
`synth/run_synth.sh` runs a full Yosys `proc`, `opt`, `fsm`, `techmap` and
`stat` flow on the top module and records `SYNTHESIS SUCCESSFUL` in
`synth/synth.log`. The only synthesis warnings are the expected conversion of
two-entry skid arrays into individual registers.

`cdc/run_cdc.py` resolves submodule clock aliases to the single top-level
clock and writes `cdc/cdc.rpt`. The design has one clock domain, so there is
no asynchronous boundary and no synchronizer requirement.

## 6. Timing status

No technology library or STA corner is installed on this host. A meaningful
WNS/TNS sign-off is therefore not possible and the timing gate is
deliberately left grey rather than reported as a fabricated pass. This is
recorded as a waiver in `REQUIREMENTS.md`.

## 7. What is not covered

1. Twelve hand-chosen mutations are a sample, not a proof; they say the suite
   catches the bug classes that were tried, not every possible bug.
2. No formal property verification was run; no formal tool is installed.
3. No timing sign-off at a named PVT corner was run; the timing gate is grey.
4. ECB is the only supported mode; CBC, CTR and GCM are outside this block.
5. Partial-beat `TKEEP` and `TSTRB` are deliberately rejected, not handled.
6. The regression covers one clock frequency and room-temperature behavioural
   simulation, not silicon or netlist simulation.

## 8. Conclusion

The RTL, handshaking, algorithm behaviour and evidence paths are complete.
The quality-gate dashboard reports the SIM, LINT, SYNTH, CDC, DOCS, FEAT and
TESTS gates as green, with TIMING as the single documented waiver.
