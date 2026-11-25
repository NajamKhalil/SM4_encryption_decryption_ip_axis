# SM4 AXI4-Stream IP - Design Specification

| Field | Value |
|-------|-------|
| Project | SM4 AXI4-Stream IP |
| Document type | Design Specification |
| Author | najam |
| Date | 2026-11-25 |
| Status | DONE |

## 1. Scope

This block implements the SM4 block cipher defined by GM/T 0002-2012 in an
AXI4-Stream shell. One input beat is one 128-bit block, one output beat is the
transformed 128-bit block. Both encryption and decryption are supported in
ECB mode. The block does not implement CBC, CTR, GCM or key management beyond
a single 128-bit key port.

## 2. Architecture

| Unit | File | Function |
|------|------|----------|
| Package | `rtl/sm4_pkg.sv` | S-box, FK/CK constants, tau and T transforms |
| Key schedule | `rtl/sm4_key_schedule.sv` | 32 round keys, one word per clock |
| Block engine | `rtl/sm4_core.sv` | 32 iterative Feistel rounds and R transform |
| Stream shell | `rtl/sm4_axis_ip.sv` | Input skid buffer, output register, sidebands |

The key schedule and the block engine are separate FSMs. A key is expanded
once and the resulting 1024-bit round-key vector remains stable while any
number of blocks are processed. Decryption uses the same vector with the
index reversed, so no second key expansion is needed when direction changes.

## 3. Interfaces

| Signal group | Width | Role |
|--------------|-------|------|
| `s_axis_t*` | 128-bit data, 16-bit strobe/keep | Block input, one beat per block |
| `m_axis_t*` | 128-bit data, 16-bit strobe/keep | Block output, one beat per block |
| `key_i` / `key_valid_i` / `key_ready_o` | 128 + handshake | Key load |
| `mode_i` | 1 | 0 encrypt, 1 decrypt |
| `axi_st_clk` / `axi_st_areset_n` | 1 + 1 | Single clock, active-low reset |

`TID`, `TDEST` and `TUSER` are captured when a block starts and replayed on
the matching output beat. Output `TKEEP` and `TSTRB` are always all ones and
`TLAST` is always asserted, because every beat is a complete block.

## 4. Algorithm detail

The non-linear transform tau applies the S-box independently to each byte.
The round mixer is
`T(x) = tau(x) xor rotl(tau,2) xor rotl(tau,10) xor rotl(tau,18) xor rotl(tau,24)`.
The key-schedule mixer is `T'(x) = tau(x) xor rotl(tau,13) xor rotl(tau,23)`.
Round keys are `K[i+4] = K[i] xor T'(K[i+1] xor K[i+2] xor K[i+3] xor CK[i])`.
The block engine evaluates `X[i+4] = X[i] xor T(X[i+1] xor X[i+2] xor
X[i+3] xor rk[i])` and applies the final reverse transform on completion.

## 5. Handshake and throughput

Input `TREADY` is a function of the registered skid-buffer occupancy only, so
it cannot depend combinationally on downstream `TREADY`. A beat accepted but
not yet consumed is held in the skid buffer and its offer is never withdrawn.
Output `TVALID` is registered and stays asserted, with stable data and
sidebands, until `TREADY` is sampled high.

One block takes 32 engine cycles plus two handshaking cycles. The input skid
buffer can absorb two beats, so a source may run ahead by two blocks while the
engine is busy. A third beat waits for `TREADY`.

## 6. Parameters and checks

`TID_WIDTH`, `TDEST_WIDTH` and `TUSER_WIDTH` must each be at least one.
Illegal values are rejected by unguarded `$fatal` statements inside a
`generate` block. Simulation-only protocol checks are compiled only when
`RTL_SIM` is defined; they flag unknown data on a handshake, partial `TKEEP`
or `TSTRB`, missing `TLAST`, and an overwritten result register.

## 7. Deliverables

| Item | Path |
|------|------|
| RTL | `sm4_axis_ip/rtl/` |
| Self-checking bench | `sm4_axis_ip/sim/` |
| Lint evidence | `sm4_axis_ip/lint/lint.log` |
| Synthesis evidence | `sm4_axis_ip/synth/synth.log` |
| CDC review | `sm4_axis_ip/cdc/cdc.rpt` |
| Quality gates | `monitor/rtl_monitor.py` |
