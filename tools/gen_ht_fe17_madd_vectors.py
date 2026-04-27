#!/usr/bin/env python3
from pathlib import Path
import random

P = (1 << 255) - 19
D = (-121665 * pow(121666, P - 2, P)) % P
D2 = (2 * D) % P


def inv(x: int) -> int:
    return pow(x, P - 2, P)


def base_point():
    y = (4 * inv(5)) % P
    x2 = ((y * y - 1) * inv(D * y * y + 1)) % P
    x = pow(x2, (P + 3) // 8, P)
    if (x * x - x2) % P != 0:
        x = (x * pow(2, (P - 1) // 4, P)) % P
    if x & 1:
        x = P - x
    return x, y


def affine_to_ext(x: int, y: int):
    return x % P, y % P, 1, (x * y) % P


def ext_double(p):
    x, y, z, t = p
    xx = x * x % P
    yy = y * y % P
    zz2 = 2 * z * z % P
    a = xx
    b = yy
    e = ((x + y) * (x + y) - a - b) % P
    g = (b + a) % P
    f = (g - zz2) % P
    h = (b - a) % P
    return e * f % P, g * h % P, f * g % P, e * h % P


def niels_from_ext(q):
    x, y, z, _t = q
    iz = inv(z)
    ax = x * iz % P
    ay = y * iz % P
    return (ay + ax) % P, (ay - ax) % P, D2 * ax * ay % P


def madd(p, qn):
    x, y, z, t = p
    ypx, ymx, xy2d = qn
    a = (y - x) * ymx % P
    b = (y + x) * ypx % P
    c = t * xy2d % P
    d = 2 * z % P
    e = (b - a) % P
    f = (d - c) % P
    g = (d + c) % P
    h = (b + a) % P
    return e * f % P, g * h % P, f * g % P, e * h % P


def scalar_mult_base(n: int):
    bx, by = base_point()
    acc = (0, 1, 1, 0)
    q = affine_to_ext(bx, by)
    while n:
        if n & 1:
            acc = madd(acc, niels_from_ext(q))
        q = ext_double(q)
        n >>= 1
    return acc


def main() -> None:
    random.seed(0xED17ADD)
    points = [scalar_mult_base(i) for i in range(1, 10)]
    points.extend(scalar_mult_base(random.randrange(1, 1 << 16)) for _ in range(12))
    qs = [niels_from_ext(scalar_mult_base(i)) for i in range(1, 10)]
    qs.extend(niels_from_ext(scalar_mult_base(random.randrange(1, 1 << 16))) for _ in range(12))

    out = Path("sim/ht_fe17_madd_vectors.mem")
    out.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with out.open("w", encoding="ascii") as f:
        for p, qn in zip(points, reversed(qs)):
            r = madd(p, qn)
            fields = list(p) + list(qn) + list(r)
            f.write(" ".join(f"{x:064x}" for x in fields) + "\n")
            count += 1
    print(f"wrote {count} vectors to {out}")


if __name__ == "__main__":
    main()
