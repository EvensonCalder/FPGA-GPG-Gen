#!/usr/bin/env python3
from pathlib import Path
import random

P = (1 << 255) - 19


def pack17(x: int) -> int:
    if not 0 <= x < P:
        raise ValueError("field element out of range")
    return x


def main() -> None:
    random.seed(0xED25519)
    values = [
        0,
        1,
        2,
        19,
        P - 1,
        P - 2,
        (1 << 254),
        (1 << 200) + 12345,
        int("1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100", 16) % P,
        int("607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db1619d", 16) % P,
    ]
    for _ in range(24):
        values.append(random.randrange(P))

    pairs = []
    for i in range(len(values) - 1):
        pairs.append((values[i], values[i + 1]))
    pairs.extend((values[i], values[-1 - i]) for i in range(12))

    out = Path("sim/ht_fe17_mul_vectors.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="ascii") as f:
        for a, b in pairs:
            c = (a * b) % P
            f.write(f"{pack17(a):064x} {pack17(b):064x} {pack17(c):064x}\n")
    print(f"wrote {len(pairs)} vectors to {out}")


if __name__ == "__main__":
    main()
