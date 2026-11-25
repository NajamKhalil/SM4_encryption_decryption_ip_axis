#!/usr/bin/env bash
# SM4 AXI4-Stream IP - simulation runner.
# Usage: ./run.sh <tb_module> [-clean] [-dump] [-compile] [-gui]
#                          [-modelsim] [-modelsim_gui]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

EXE="my_sim_exe"
LOG="sim.log"
VCD="simulation.vcd"

# Icarus is installed outside the default PATH on some Windows hosts. Adding
# the standard MSYS paths is harmless on machines where tools are already
# available from PATH.
for tool_dir in "/c/iverilog/bin" "/c/Program Files/Icarus Verilog/bin"; do
  if [ -d "$tool_dir" ]; then
    PATH="$tool_dir:$PATH"
  fi
done
export PATH

usage() {
  cat <<'EOF'
Usage: ./run.sh <tb_module> [options]

  <tb_module>    Top-level testbench module, e.g. tb_sm4_axis_ip
  -h, --help     Show this help
  -clean         Remove compiled binary, log and waveform files
  -dump          Enable VCD waveform dumping (simulation.vcd)
  -compile       Compile only; do not run
  -gui           Run with -dump and open GTKwave if available
  -modelsim      Compile and run with ModelSim/Questa
  -modelsim_gui  Compile and run with the ModelSim/Questa GUI
EOF
}

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

case "$1" in
  -h|--help) usage; exit 0 ;;
esac

TB="$1"
shift

CLEAN=0
DUMP=0
COMPILE=0
GUI=0
MODELSIM=0
MODELSIM_GUI=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)      usage; exit 0 ;;
    -clean)         CLEAN=1 ;;
    -dump)          DUMP=1 ;;
    -compile)       COMPILE=1 ;;
    -gui)           GUI=1; DUMP=1 ;;
    -modelsim)      MODELSIM=1 ;;
    -modelsim_gui)  MODELSIM_GUI=1; GUI=1 ;;
    *) echo "ERROR: unknown option $1"; usage; exit 1 ;;
  esac
  shift
done

if [ "$CLEAN" -eq 1 ]; then
  rm -f "$EXE" "$EXE.vvp" "$LOG" "$VCD" "transcript" "vsim.wlf"
  echo "CLEAN: simulation artifacts removed"
  exit 0
fi

if [ ! -f "$TB.sv" ]; then
  echo "ERROR: testbench source $TB.sv not found in $SCRIPT_DIR"
  exit 1
fi

if [ "$MODELSIM" -eq 1 ] || [ "$MODELSIM_GUI" -eq 1 ]; then
  FLAGS="+define+RTL_SIM"
  if [ "$DUMP" -eq 1 ]; then
    FLAGS="$FLAGS +define+DUMP_VCD"
  fi
  vlog -sv $FLAGS -f f_list.f "$TB.sv" || exit 1
  if [ "$COMPILE" -eq 1 ]; then
    echo "COMPILE ONLY: ModelSim work library updated"
    exit 0
  fi
  if [ "$MODELSIM_GUI" -eq 1 ]; then
    vsim -gui work."$TB" -do "run -all" | tee "$LOG"
  else
    vsim -batch work."$TB" -do "run -all; quit" | tee "$LOG"
  fi
  exit "${PIPESTATUS[0]}"
fi

DEFINES="-D RTL_SIM"
if [ "$DUMP" -eq 1 ]; then
  DEFINES="$DEFINES -D DUMP_VCD"
fi

iverilog -g2012 -Wall $DEFINES -s "$TB" -o "$EXE.vvp" -f f_list.f "$TB.sv" || exit 1
echo "COMPILE: $TB -> $EXE.vvp"

if [ "$COMPILE" -eq 1 ]; then
  echo "COMPILE ONLY: use ./run.sh $TB to execute"
  exit 0
fi

vvp "$EXE.vvp" | tee "$LOG"
STATUS="${PIPESTATUS[0]}"

if [ "$GUI" -eq 1 ] && [ -f "$VCD" ] && command -v gtkwave >/dev/null 2>&1; then
  gtkwave "$VCD" &
fi

exit "$STATUS"
