"""Structural clock-domain crossing review for the SM4 AXI4-Stream IP.

The design is intentionally single-clock. This script derives that fact from
the RTL instead of relying on prose: it collects every clock named in a
posedge event control and writes a short review report.
"""
from __future__ import annotations

import re
from pathlib import Path

BLOCK = Path(__file__).resolve().parent.parent
RTL = BLOCK / "rtl"
REPORT = BLOCK / "cdc" / "cdc.rpt"

CLOCK = re.compile(r"@\s*\(\s*posedge\s+([A-Za-z_][A-Za-z0-9_]*)")
RESET = re.compile(r"or\s+negedge\s+([A-Za-z_][A-Za-z0-9_]*)")


def main() -> None:
    clocks: set[str] = set()
    resets: set[str] = set()
    for path in sorted(RTL.glob("*.sv")):
        text = path.read_text(encoding="utf-8")
        clocks.update(CLOCK.findall(text))
        resets.update(RESET.findall(text))

    # Submodule ports are named clk/arst_n but are tied to the top-level
    # nets through named instance connections. Resolve those aliases before
    # counting domains, otherwise a single clock is mistaken for two.
    top_text = (RTL / "sm4_axis_ip.sv").read_text(encoding="utf-8")
    aliases = {port: net for port, net in
               re.findall(r"\.(\w+)\s*\(\s*(\w+)\s*\)", top_text)
               if port in clocks or port in resets}
    clocks = {aliases.get(c, c) for c in clocks}
    resets = {aliases.get(r, r) for r in resets}

    lines = [
        "CDC STRUCTURAL REVIEW - sm4_axis_ip",
        "Method: scan every always_ff event control in rtl/*.sv.",
        f"Clocks found: {', '.join(sorted(clocks)) or 'none'}",
        f"Asynchronous resets found: {', '.join(sorted(resets)) or 'none'}",
    ]
    if len(clocks) <= 1:
        lines += [
            "Result: single-clock design; no asynchronous boundary to cross.",
            "Synchronizers required: none.",
            "0 violations",
        ]
        verdict = 0
    else:
        lines += [
            "Result: multiple clocks detected; manual CDC sign-off required.",
            "1 violation",
        ]
        verdict = 1

    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"CDC report written: {REPORT.relative_to(BLOCK)}")
    raise SystemExit(verdict)


if __name__ == "__main__":
    main()
