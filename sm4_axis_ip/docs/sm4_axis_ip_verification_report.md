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
zero mismatches. The standard known-answer vector was checked against the
published constant as well as against the independent behavioural model.

## 2. Simulation evidence

`sim/run.sh tb_sm4_axis_ip` writes the final report to `sim/sim.log`:

```
-------------------------------------
- Report Phase
-------------------------------------
MATCH      COUNTER     = 37
MISMATCH   COUNTER     = 0
BEATS      CHECKED     = 37
RESULT = PASS (37 matches, 0 mismatches)
```

The bench includes the published vector with key and plaintext
`0123456789ABCDEFFEDCBA9876543210` and expected ciphertext
`681EDF34D206965E86B3E94F536E4246`. Decrypting that ciphertext with the same
key returns the original plaintext. Random traffic, slave stalls and master
backpressure were layered on top of those directed checks.

## 3. Algorithm cross-check

The 256 S-box entries in the package were compared byte for byte with the
reference table published in the OpenSSL SM4 implementation. All 256 values
are identical. The known-answer test then confirms the surrounding key
schedule, rotations and final reverse transform.

## 4. Lint, synthesis and CDC evidence

`lint/run_lint.sh` combines `iverilog -Wall` elaboration with a Yosys
`check -assert` pass and records `0 errors` in `lint/lint.log`.
`synth/run_synth.sh` runs a full Yosys `proc`, `opt`, `fsm`, `techmap` and
`stat` flow on the top module and records `SYNTHESIS SUCCESSFUL` in
`synth/synth.log`. The only synthesis warnings are the expected conversion of
two-entry skid arrays into individual registers.

`cdc/run_cdc.py` resolves submodule clock aliases to the single top-level
clock and writes `cdc/cdc.rpt`. The design has one clock domain, so there is
no asynchronous boundary and no synchronizer requirement.

## 5. Timing status

No technology library or STA corner is installed on this host. A meaningful
WNS/TNS sign-off is therefore not possible and the timing gate is
deliberately left grey rather than reported as a fabricated pass. This is
recorded as a waiver in `REQUIREMENTS.md`.

## 6. Conclusion

The RTL, handshaking, algorithm behaviour and evidence paths are complete.
The quality-gate dashboard reports the SIM, LINT, SYNTH, CDC, DOCS, FEAT and
TESTS gates as green, with TIMING as the single documented waiver.
