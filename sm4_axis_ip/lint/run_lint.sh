#!/usr/bin/env bash
# SM4 AXI4-Stream IP - lint runner.
# Combines Icarus Verilog -Wall elaboration with Yosys structural checks.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/lint/lint.log"
: > "$LOG"

for tool_dir in "/c/iverilog/bin" \
                "/c/Users/najam/AppData/Local/Programs/Python/Python312/Scripts" \
                "/usr/local/bin"; do
  if [ -d "$tool_dir" ]; then
    PATH="$tool_dir:$PATH"
  fi
done
export PATH

cd "$ROOT/sim" || exit 1
if ! iverilog -g2012 -Wall -tnull -s sm4_axis_ip -f f_list.f >> "$LOG" 2>&1; then
  echo "ERROR: Icarus lint/elaboration failed; see lint/lint.log"
  exit 1
fi

cd "$ROOT/synth" || exit 1
if ! yowasp-yosys -p "read_verilog -sv ../rtl/sm4_pkg.sv; \
read_verilog -sv ../rtl/sm4_key_schedule.sv; \
read_verilog -sv ../rtl/sm4_core.sv; \
read_verilog -sv ../rtl/sm4_axis_ip.sv; \
hierarchy -check -top sm4_axis_ip; proc; opt; check -assert; stat" \
  >> "$LOG" 2>&1; then
  echo "ERROR: Yosys lint check failed; see lint/lint.log"
  exit 1
fi

if grep -q 'ERROR' "$LOG"; then
  echo "ERROR: lint reported an ERROR; see lint/lint.log"
  exit 1
fi

{
  echo "---------------------------------------------------------------------"
  echo "LINT SUCCESSFUL: iverilog -Wall and Yosys check -assert"
  echo "0 errors"
} >> "$LOG"

echo "LINT SUCCESSFUL: see lint/lint.log"
