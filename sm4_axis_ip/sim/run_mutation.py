"""Mutation campaign for the SM4 AXI4-Stream IP regression suite.

A testbench that has never failed proves nothing. Each mutation below is
injected into a temporary copy of the RTL, one at a time, and the full
multi-seed regression is re-run against it. The shipping RTL is never edited.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

SIM = Path(__file__).resolve().parent
BLOCK = SIM.parent
RTL = BLOCK / "rtl"
RPT = SIM / "mutation.rpt"
LOG = SIM / "mutation.log"
TB = "tb_sm4_axis_ip"
RUNS = int(os.environ.get("SM4_MUT_RUNS", os.environ.get("SM4_REG_RUNS", "24")))
BLOCKS = int(os.environ.get("SM4_MUT_BLOCKS",
                            os.environ.get("SM4_REG_BLOCKS", "32")))
BASE_SEED = int(os.environ.get("SM4_MUT_BASE_SEED", "22075"))
WORKERS = int(os.environ.get("SM4_MUT_WORKERS", "4"))


@dataclass(frozen=True)
class Mutation:
    mid: str
    file: str
    old: str
    new: str
    description: str


MUTATIONS: tuple[Mutation, ...] = (
    Mutation("M01", "sm4_pkg.sv",
             "8'h00: f_sbox = 8'hD6;",
             "8'h00: f_sbox = 8'hD7;",
             "S-box byte 00 maps to D7 instead of D6"),
    Mutation("M02", "sm4_pkg.sv",
             "0: f_fk = 32'hA3B1BAC6;",
             "0: f_fk = 32'hA3B1BAC7;",
             "FK[0] is corrupted by one LSB"),
    Mutation("M03", "sm4_pkg.sv",
             "0:  f_ck = 32'h00070E15;",
             "0:  f_ck = 32'h00070E16;",
             "CK[0] is corrupted by one LSB"),
    Mutation("M04", "sm4_pkg.sv",
             "f_t = t ^ f_rotl(t, 2) ^ f_rotl(t, 10) ^ f_rotl(t, 18) "
             "^ f_rotl(t, 24);",
             "f_t = t ^ f_rotl(t, 3) ^ f_rotl(t, 10) ^ f_rotl(t, 18) "
             "^ f_rotl(t, 24);",
             "round mixer rotates tau by 3 instead of 2"),
    Mutation("M05", "sm4_pkg.sv",
             "f_t_key = t ^ f_rotl(t, 13) ^ f_rotl(t, 23);",
             "f_t_key = t ^ f_rotl(t, 14) ^ f_rotl(t, 23);",
             "key mixer rotates tau by 14 instead of 13"),
    Mutation("M06", "sm4_core.sv",
             "assign rk_index_c = mode_q ? (5'd31 - round_q) : round_q;",
             "assign rk_index_c = round_q;",
             "decrypt consumes round keys in forward order"),
    Mutation("M07", "sm4_core.sv",
             "result_o <= {xnew_c, x3_q, x2_q, x1_q};",
             "result_o <= {x3_q, x2_q, x1_q, xnew_c};",
             "final reverse transform emits words in the wrong order"),
    Mutation("M08", "sm4_core.sv",
             "if (round_q == 5'd31) begin",
             "if (round_q == 5'd30) begin",
             "engine stops after 31 rounds instead of 32"),
    Mutation("M09", "sm4_axis_ip.sv",
             "assign m_axis_tlast_o  = 1'b1;",
             "assign m_axis_tlast_o  = 1'b0;",
             "output TLAST is forced low"),
    Mutation("M10", "sm4_axis_ip.sv",
             "assign m_axis_tkeep_o  = {TKEEP_WIDTH{1'b1}};",
             "assign m_axis_tkeep_o  = {TKEEP_WIDTH{1'b0}};",
             "output TKEEP is forced to all zeros"),
    Mutation("M11", "sm4_axis_ip.sv",
             "result_id_q    <= active_id_q;",
             "result_id_q    <= '0;",
             "output TID no longer replays the captured sideband"),
    Mutation("M12", "sm4_axis_ip.sv",
             "assign s_axis_tready_o = (in_count_q < 2'd2);",
             "assign s_axis_tready_o = 1'b1;",
             "slave ready ignores skid-buffer occupancy"),
)


@dataclass
class Outcome:
    mid: str
    description: str
    killed: bool
    first_failure: str
    mismatches: int
    detail: str


def find_tool(name: str) -> str:
    os.environ["PATH"] = r"C:\iverilog\bin" + os.pathsep + os.environ.get("PATH", "")
    tool = shutil.which(name)
    if tool is None:
        raise RuntimeError(f"{name} not found; install Icarus Verilog")
    return tool


def run_mutant(mutation: Mutation, iverilog: str, vvp: str) -> Outcome:
    with tempfile.TemporaryDirectory(prefix=f"sm4_{mutation.mid.lower()}_") as tmp:
        work = Path(tmp)
        (work / "rtl").mkdir()
        (work / "sim").mkdir()
        for src in RTL.glob("*.sv"):
            shutil.copy2(src, work / "rtl" / src.name)
        shutil.copy2(SIM / "f_list.f", work / "sim" / "f_list.f")
        shutil.copy2(SIM / f"{TB}.sv", work / "sim" / f"{TB}.sv")

        target = work / "rtl" / mutation.file
        text = target.read_text(encoding="utf-8")
        count = text.count(mutation.old)
        if count != 1:
            raise RuntimeError(f"{mutation.mid} patch matched {count} lines")
        target.write_text(text.replace(mutation.old, mutation.new),
                          encoding="utf-8")

        compile_cmd = [iverilog, "-g2012", "-Wall", "-D", "RTL_SIM",
                       "-s", TB, "-o", "mutant.vvp", "-f", "f_list.f",
                       f"{TB}.sv"]
        compiled = subprocess.run(compile_cmd, cwd=work / "sim",
                                  capture_output=True, text=True)
        if compiled.returncode != 0:
            first = next((ln.strip() for ln in
                          (compiled.stderr + compiled.stdout).splitlines()
                          if ln.strip()), "compile failed")
            return Outcome(mutation.mid, mutation.description, True,
                           first, 0, "compile failed")

        for run in range(1, RUNS + 1):
            seed = BASE_SEED + run * 7919
            result = subprocess.run(
                [vvp, "mutant.vvp", f"+SEED={seed}", f"+BLOCKS={BLOCKS}"],
                cwd=work / "sim", capture_output=True, text=True)
            out = result.stdout + result.stderr
            lines = out.splitlines()
            has_fail = result.returncode != 0 or any(
                ln.startswith("RESULT = FAIL") or ln.startswith("ERROR:")
                for ln in lines)
            if not has_fail:
                continue

            first = next((ln.strip() for ln in lines
                          if ln.startswith("ERROR:") or
                          ln.startswith("RESULT = FAIL")),
                         f"RESULT = FAIL (run {run}, status {result.returncode})")
            m = re.search(r"^MISMATCH\s+COUNTER\s+=\s+(\d+)", out, re.M)
            return Outcome(mutation.mid, mutation.description, True, first,
                           int(m.group(1)) if m else 0,
                           f"first failing run {run} of {RUNS}, seed {seed}")

        return Outcome(mutation.mid, mutation.description, False,
                       "RESULT = PASS", 0, f"all {RUNS} runs passed")


def main() -> None:
    if RUNS < 1 or BLOCKS < 1 or WORKERS < 1:
        raise SystemExit("RUNS, BLOCKS and WORKERS must all be >= 1")

    iverilog = find_tool("iverilog")
    vvp = find_tool("vvp")
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        outcomes = list(pool.map(
            lambda mut: run_mutant(mut, iverilog, vvp), MUTATIONS))
    outcomes.sort(key=lambda o: o.mid)

    killed = [o for o in outcomes if o.killed]
    survivors = [o for o in outcomes if not o.killed]
    total = len(MUTATIONS)
    verdict = "PASS" if not survivors else "FAIL"

    lines = [
        "A testbench that has never failed proves nothing. Twelve deliberate "
        "bugs were injected into temporary copies of the RTL, one at a time, "
        "and the full multi-seed regression was re-run against each.",
        "Every mutation ran against the final revision of the RTL and "
        "testbench, so these numbers describe the code that ships.",
        f"REGRESSION = {RUNS} runs x {BLOCKS} encrypt blocks x {BLOCKS} decrypt "
        "blocks per mutant",
        "---------------------------------------------------------------------",
        f"Caught - {len(killed)} of {total}",
        "# | Mutation | First failure reported",
    ]
    for outcome in killed:
        count = f" ({outcome.mismatches} mismatches)" if outcome.mismatches else ""
        lines.append(f"{outcome.mid} | {outcome.description} | "
                     f"`{outcome.first_failure}`{count}")
    lines += [
        f"Survivors - {len(survivors)} of {total}",
    ]
    if survivors:
        lines.append("# | Mutation | Why it cannot be observed")
        for outcome in survivors:
            lines.append(f"{outcome.mid} | {outcome.description} | "
                         f"{outcome.detail} - this is a coverage hole")
    else:
        lines.append("No mutants survived; no equivalence arguments are "
                     "required.")
    lines += [
        "---------------------------------------------------------------------",
        f"RESULT = {verdict} (mutation campaign: {len(killed)}/{total} killed, "
        f"{len(survivors)} survivors)",
    ]

    report = "\n".join(lines) + "\n"
    RPT.write_text(report, encoding="utf-8")
    LOG.write_text(report, encoding="utf-8")
    print(f"MUTATION CAMPAIGN {verdict}: {len(killed)}/{total} killed, "
          f"{len(survivors)} survivors")
    print(f"Reports: {RPT.relative_to(BLOCK)}, {LOG.relative_to(BLOCK)}")
    raise SystemExit(0 if verdict == "PASS" else 1)


if __name__ == "__main__":
    main()
