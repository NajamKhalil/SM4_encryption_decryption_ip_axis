#!/usr/bin/env bash
# SM4 AXI4-Stream IP - synthesis runner (Yosys).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

for tool_dir in "/c/Users/najam/AppData/Local/Programs/Python/Python312/Scripts" \
                "/usr/local/bin"; do
  if [ -d "$tool_dir" ]; then
    PATH="$tool_dir:$PATH"
  fi
done
export PATH

if ! command -v yowasp-yosys >/dev/null 2>&1; then
  echo "ERROR: yowasp-yosys not found in PATH" | tee synth.log
  exit 1
fi

if ! yowasp-yosys -s synth.ys > synth.log 2>&1; then
  echo "ERROR: synthesis failed; see synth.log"
  exit 1
fi

if grep -q 'ERROR' synth.log; then
  echo "ERROR: synthesis reported an ERROR; see synth.log"
  exit 1
fi

{
  echo "---------------------------------------------------------------------"
  echo "SYNTHESIS SUCCESSFUL: Yosys, top module sm4_axis_ip"
  echo "0 errors"
} >> synth.log

echo "SYNTHESIS SUCCESSFUL: see synth/synth.log"
