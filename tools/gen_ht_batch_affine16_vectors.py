#!/usr/bin/env python3
from pathlib import Path
from gen_ht_fe17_madd_vectors import P, scalar_mult_base, inv


def encode_public(point):
    x, y, z, _t = point
    iz = inv(z)
    ax = x * iz % P
    ay = y * iz % P
    return ay | ((ax & 1) << 255)


def main() -> None:
    base = [
        0x6F8EFF1F84F125A1E612DEDE40146D9D5549E02B76356981EF0A589CA4EE9438,
        0x4FE94D9006F020A5A3C080D96827FFFD3C010AC0F12E7A42CB33284F86837C30,
        0x5F8EFF1F84F125A1E612DEDE40146D9D5549E02B76356981EF0A589CA4EE9438,
        0x6FE94D9006F020A5A3C080D96827FFFD3C010AC0F12E7A42CB33284F86837C30,
    ]
    scalars = [(base[i % 4] + i * 0x12345) % (1 << 255) for i in range(16)]
    out = Path("sim/ht_batch_affine16_vectors.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="ascii") as f:
        for i, s in enumerate(scalars):
            p = scalar_mult_base(s)
            pub = encode_public(p)
            f.write(" ".join(f"{v:064x}" for v in (*p, pub, i + 1)) + "\n")
    print(f"wrote {len(scalars)} vectors to {out}")


if __name__ == "__main__":
    main()
