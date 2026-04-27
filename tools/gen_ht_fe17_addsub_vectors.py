#!/usr/bin/env python3
from pathlib import Path
import random

P = (1 << 255) - 19


def main() -> None:
    random.seed(0xA55A17)
    values = [0, 1, 2, 19, P - 1, P - 2, 1 << 254]
    for _ in range(32):
        values.append(random.randrange(P))

    pairs = []
    for i in range(len(values) - 1):
        pairs.append((values[i], values[i + 1]))
    pairs.extend((values[i], values[-1 - i]) for i in range(16))

    out = Path("sim/ht_fe17_addsub_vectors.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="ascii") as f:
        for a, b in pairs:
            f.write(f"0 {a:064x} {b:064x} {(a + b) % P:064x}\n")
            f.write(f"1 {a:064x} {b:064x} {(a - b) % P:064x}\n")
    print(f"wrote {len(pairs) * 2} vectors to {out}")


if __name__ == "__main__":
    main()
