#!/usr/bin/env python3
"""Extract base_rom1 initial data and write as hex for $readmemh."""

import re, sys

SRC = "saif_ed25519_ref/baseP_mult/base_rom1.sv"

entries = {}   # (pos, j) -> [yp, ym, xy]  each is a list of 10 32-bit signed ints

pos = None
with open(SRC) as f:
    for line in f:
        m = re.match(r"\s*//\s*pos\s*=\s*(\d+)", line)
        if m:
            pos = int(m.group(1))
            continue
        # base[pos][j][field] = '{v0, v1, ..., v9};
        m = re.match(r"\s*base\[.*\]\[(\d+)\]\[(\d+)\]\s*=\s*'\{([^}]+)\}", line)
        if m:
            j = int(m.group(1))
            field = int(m.group(2))
            vals_str = m.group(3)
            vals = [int(v.strip()) for v in vals_str.split(",")]
            if (pos, j) not in entries:
                entries[(pos, j)] = [[], [], []]
            entries[(pos, j)][field] = vals

# Write flat ROM: addr = pos * 8 * 3 * 10 + j * 3 * 10 + field * 10 + limb
# Total: 32 * 8 * 3 * 10 = 7680 entries, each 32-bit hex
TOTAL = 32 * 8 * 3 * 10
rom = [0] * TOTAL

for (p, j), fields in entries.items():
    for field in range(3):
        for limb in range(10):
            addr = p * (8 * 3 * 10) + j * (3 * 10) + field * 10 + limb
            if field < len(fields) and limb < len(fields[field]):
                val = fields[field][limb]
                # Convert signed 32-bit to unsigned hex
                if val < 0:
                    val = val & 0xFFFFFFFF
                rom[addr] = val

with open("build/fixedbase_rom.mem", "w") as out:
    for v in rom:
        out.write(f"{v:08x}\n")

print(f"Generated build/fixedbase_rom.mem with {len(rom)} entries")
