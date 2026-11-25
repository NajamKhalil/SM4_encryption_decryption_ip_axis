# SM4 AXI4-Stream IP - Feature Checklist

| # | Feature | Status | Evidence |
|---|---------|--------|----------|
| F1 | 128-bit key and 128-bit block datapath | DONE | `rtl/sm4_axis_ip.sv` |
| F2 | 256-entry SM4 S-box from the standard | DONE | `rtl/sm4_pkg.sv` |
| F3 | 32-round key schedule with FK and CK | DONE | `rtl/sm4_key_schedule.sv` |
| F4 | 32-round unbalanced Feistel encrypt datapath | DONE | `rtl/sm4_core.sv` |
| F5 | Decrypt using the same keys in reverse order | DONE | `rtl/sm4_core.sv` |
| F6 | AXI4-Stream input with registered ready and skid buffer | DONE | `rtl/sm4_axis_ip.sv` |
| F7 | AXI4-Stream output with backpressure and TLAST | DONE | `rtl/sm4_axis_ip.sv` |
| F8 | Full-beat TKEEP policy (all bytes valid or error) | DONE | `rtl/sm4_axis_ip.sv` |
| F9 | Elaboration checks on illegal parameters | DONE | `rtl/sm4_axis_ip.sv` |
| F10 | Simulation-only protocol checks under `RTL_SIM` | DONE | `rtl/sm4_axis_ip.sv` |
| F11 | Self-checking testbench with independent software reference model | DONE | `sim/tb_sm4_axis_ip.sv` |
| F12 | Standard known-answer encrypt and decrypt vectors | DONE | `sim/tb_sm4_axis_ip.sv` |
| F13 | Backpressure and TLAST tests, TKEEP policy checks under `RTL_SIM` | DONE | `sim/tb_sm4_axis_ip.sv` |
| F14 | Lint report on the contracted evidence path | DONE | `lint/lint.log` |
| F15 | Synthesis report on the contracted evidence path | DONE | `synth/synth.log` |
| F16 | Design spec, test plan and verification report | DONE | `docs/` |
| F17 | Quality-gate dashboard wired to this block | DONE | `monitor/rtl_monitor.py` |
| F18 | Seedable multi-seed regression with replayable random keys and backpressure | DONE | `sim/regression.log` |
| F19 | Mutation campaign proving the regression can fail | DONE | `sim/mutation.rpt` |

## Waived

| # | Feature | Status | Evidence |
|---|---------|--------|----------|
| W1 | STA sign-off at a named FPGA/ASIC corner | N/A | No STA library installed; timing gate intentionally grey |
| W2 | Formal property verification | N/A | No formal tool installed; `fpv/` reserved with a placeholder |
