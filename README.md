# SM4 encryption/decryption IP with AXI4-Stream interface

SystemVerilog implementation of the SM4 block cipher (128-bit block, 128-bit key,
32 rounds) with an AXI4-Stream input and output handshake.

The design uses a quality-gate dashboard set up first, each
block uses the fixed `rtl/ sim/ docs/ fpv/ synth/ vcsmx/` skeleton, and every
quality gate is backed by a tool report on the contracted path.

Algorithm reference: `SM4_Presentation.pdf` (included in this repository).
