#!/usr/bin/env python3
from pathlib import Path
import random
from gen_ht_fe17_madd_vectors import scalar_mult_base, ext_double


def main() -> None:
    random.seed(0xD0B1E)
    points = [scalar_mult_base(i) for i in range(1, 12)]
    points.extend(scalar_mult_base(random.randrange(1, 1 << 16)) for _ in range(14))

    out = Path("sim/ht_fe17_dbl_vectors.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="ascii") as f:
        for p in points:
            r = ext_double(p)
            f.write(" ".join(f"{x:064x}" for x in (list(p) + list(r))) + "\n")
    print(f"wrote {len(points)} vectors to {out}")


if __name__ == "__main__":
    main()
