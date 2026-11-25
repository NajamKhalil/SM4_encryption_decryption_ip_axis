#!/usr/bin/env bash
# SM4 AXI4-Stream IP - multi-seed regression runner.
# Usage: ./run_regression.sh [runs] [blocks_per_phase]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

for tool_dir in "/c/iverilog/bin" "/c/Program Files/Icarus Verilog/bin"; do
  if [ -d "$tool_dir" ]; then
    PATH="$tool_dir:$PATH"
  fi
done
export PATH

TB="tb_sm4_axis_ip"
RUN_DIR="regression/runs"
EXE="$RUN_DIR/regression.vvp"
LOG="regression.log"
RUNS="${1:-${SM4_REG_RUNS:-24}}"
BLOCKS="${2:-${SM4_REG_BLOCKS:-32}}"
BASE_SEED="${SM4_REG_BASE_SEED:-11025}"

case "$RUNS" in
  ''|*[!0-9]*) echo "RESULT = FAIL (runs must be a positive integer)"; exit 1 ;;
esac
case "$BLOCKS" in
  ''|*[!0-9]*) echo "RESULT = FAIL (blocks must be a positive integer)"; exit 1 ;;
esac
if [ "$RUNS" -lt 1 ] || [ "$BLOCKS" -lt 1 ]; then
  echo "RESULT = FAIL (runs and blocks must be >= 1)"
  exit 1
fi

mkdir -p "$RUN_DIR"
rm -f "$RUN_DIR"/*.log "$EXE"

if ! iverilog -g2012 -Wall -D RTL_SIM -s "$TB" -o "$EXE" -f f_list.f \
     "$TB.sv" > "$RUN_DIR/compile.log" 2>&1; then
  echo "RESULT = FAIL (regression compile failed; see $RUN_DIR/compile.log)" > "$LOG"
  exit 1
fi

{
  echo "SM4 AXI4-Stream IP - multi-seed regression"
  echo "COMPILE     = iverilog -g2012 -Wall -D RTL_SIM"
  echo "RUNS        = $RUNS"
  echo "BLOCKS      = $BLOCKS encrypt and $BLOCKS decrypt per run"
  echo "BASE SEED   = $BASE_SEED"
  echo "---------------------------------------------------------------------"
} > "$LOG"

total_beats=0
failures=0

for i in $(seq 1 "$RUNS"); do
  seed=$((BASE_SEED + i * 7919))
  run_log="$RUN_DIR/run_$(printf '%03d' "$i")_seed_${seed}.log"
  vvp "$EXE" +SEED="$seed" +BLOCKS="$BLOCKS" > "$run_log" 2>&1
  status=$?
  result="$(grep -m1 '^RESULT' "$run_log" || true)"
  beats="$(sed -n 's/^BEATS      CHECKED     = //p' "$run_log" | tail -1)"

  if [ "$status" -eq 0 ] && printf '%s\n' "$result" | grep -q '^RESULT = PASS'; then
    printf 'RUN %03d SEED %-10s %s BEATS=%s\n' \
      "$i" "$seed" "$result" "${beats:-0}" >> "$LOG"
    total_beats=$((total_beats + ${beats:-0}))
  else
    failures=$((failures + 1))
    printf 'RUN %03d SEED %-10s FAILED status=%s %s\n' \
      "$i" "$seed" "$status" "${result:-no RESULT line}" >> "$LOG"
    grep -m1 -E '^(ERROR|RESULT)' "$run_log" | sed 's/^/FIRST FAILURE: /' >> "$LOG"
  fi
done

{
  echo "---------------------------------------------------------------------"
  echo "TOTAL BEATS = $total_beats"
  echo "FAILURES    = $failures"
  if [ "$failures" -eq 0 ]; then
    echo "RESULT = PASS (multi-seed: $RUNS/$RUNS runs, $total_beats beats, 0 failures)"
  else
    echo "RESULT = FAIL (multi-seed: $failures of $RUNS runs failed)"
  fi
} >> "$LOG"

if [ "$failures" -eq 0 ]; then
  echo "REGRESSION SUCCESSFUL: see sim/regression.log"
  exit 0
fi

echo "REGRESSION FAILED: see sim/regression.log"
exit 1
