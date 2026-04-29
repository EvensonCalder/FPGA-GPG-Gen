#!/usr/bin/env python3
from pathlib import Path
from gen_ht_fe17_madd_vectors import P, D2, base_point, affine_to_ext, ext_double


def inv(x: int) -> int:
    return pow(x, P - 2, P)


def ext_add(p, q):
    x1, y1, z1, t1 = p
    x2, y2, z2, t2 = q
    ypx = (y2 + x2) * inv(z2) % P
    ymx = (y2 - x2) * inv(z2) % P
    xy2d = D2 * x2 * y2 * inv(z2 * z2 % P) % P
    a = (y1 - x1) * ymx % P
    b = (y1 + x1) * ypx % P
    c = t1 * xy2d % P
    d = 2 * z1 % P
    e = (b - a) % P
    f = (d - c) % P
    g = (d + c) % P
    h = (b + a) % P
    return e * f % P, g * h % P, f * g % P, e * h % P


def affine_niels(p):
    x, y, z, _t = p
    iz = inv(z)
    ax = x * iz % P
    ay = y * iz % P
    return (ay + ax) % P, (ay - ax) % P, D2 * ax * ay % P


def scalar_mul_point(point, n):
    acc = (0, 1, 1, 0)
    q = point
    while n:
        if n & 1:
            acc = ext_add(acc, q)
        q = ext_double(q)
        n >>= 1
    return acc


def main() -> None:
    window_bits = 9
    digits = (256 + window_bits - 1) // window_bits
    table_entries_per_digit = 1 << (window_bits - 1)

    bx, by = base_point()
    base = affine_to_ext(bx, by)
    entries = []
    for pos in range(digits):
        radix_point = base
        for _ in range(window_bits * pos):
            radix_point = ext_double(radix_point)
        for j in range(table_entries_per_digit):
            multiple = scalar_mul_point(radix_point, j + 1)
            entries.append(affine_niels(multiple))

    out = Path("build/ht_fixedbase_table.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="ascii") as f:
        for ypx, ymx, xy2d in entries:
            f.write(f"{ypx:064x}_{ymx:064x}_{xy2d:064x}\n")
    print(f"wrote {len(entries)} entries to {out}")


if __name__ == "__main__":
    main()
