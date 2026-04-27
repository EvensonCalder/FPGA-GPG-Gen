#!/usr/bin/env python3
from pathlib import Path
import random

P = (1 << 255) - 19


def main() -> None:
    random.seed(0xFE17AA)
    values = [
        0,
        1,
        2,
        19,
        P - 1,
        P - 2,
        1 << 254,
        (1 << 200) + 12345,
        int("1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100", 16) % P,
        int("607fae1c03ac3b701969327b69c54944c42cec92f44a84ba605afdef9db1619d", 16) % P,
    ]
    for _ in range(35):
        values.append(random.randrange(P))

    out = Path("sim/ht_fe17_square_vectors.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="ascii") as f:
        for a in values:
            c = (a * a) % P
            f.write(f"{a:064x} {c:064x}\n")
    print(f"wrote {len(values)} vectors to {out}")


if __name__ == "__main__":
    main()
