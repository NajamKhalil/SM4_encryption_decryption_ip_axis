# SM4 AXI4-Stream IP - Feature Checklist

| # | Feature | Status | Evidence |
|---|---------|--------|----------|
| F1 | 128-bit key and 128-bit block datapath | PLANNED | `rtl/sm4_pkg.sv` |
| F2 | 256-entry SM4 S-box from the standard | PLANNED | `rtl/sm4_pkg.sv` |
| F3 | 32-round key schedule with FK and CK | PLANNED | `rtl/sm4_key_schedule.sv` |
| F4 | 32-round unbalanced Feistel encrypt datapath | PLANNED | `rtl/sm4_core.sv` |
| F5 | Decrypt using the same keys in reverse order | PLANNED | `rtl/sm4_core.sv` |
| F6 | AXI4-Stream input with registered ready and skid buffer | PLANNED | `rtl/sm4_axis_ip.sv` |
| F7 | AXI4-Stream output with backpressure and TLAST | PLANNED | `rtl/sm4_axis_ip.sv` |
| F8 | Full-beat TKEEP policy (all bytes valid or error) | PLANNED | `rtl/sm4_axis_ip.sv` |
| F9 | Elaboration checks on illegal parameters | PLANNED | `rtl/sm4_axis_ip.sv` |
| F10 | Simulation-only protocol checks under `RTL_SIM` | PLANNED | `rtl/sm4_axis_ip.sv` |
| F11 | Self-checking testbench with independent software reference model | PLANNED | `sim/tb_sm4_axis_ip.sv` |
| F12 | Standard known-answer encrypt and decrypt vectors | PLANNED | `sim/tb_sm4_axis_ip.sv` |
| F13 | Backpressure, TLAST and corrupt-TKEEP scenarios | PLANNED | `sim/tb_sm4_axis_ip.sv` |
| F14 | Lint report on the contracted evidence path | PLANNED | `lint/lint.log` |
| F15 | Synthesis report on the contracted evidence path | PLANNED | `synth/synth.log` |
| F16 | Design spec, test plan and verification report | PLANNED | `docs/` |
| F17 | Quality-gate dashboard wired to this block | PLANNED | `monitor/rtl_monitor.py` |

## Waived

| # | Feature | Status | Evidence |
|---|---------|--------|----------|
| W1 | STA sign-off at a named FPGA/ASIC corner | N/A | No STA tool installed on this machine; timing gate stays grey, never green |
| W2 | Formal property verification | N/A | No formal tool installed; `fpv/` reserved with a placeholder |
