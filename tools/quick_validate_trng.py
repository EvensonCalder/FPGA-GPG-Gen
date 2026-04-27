#!/usr/bin/env python3
import argparse
import collections
import math
import os


def erfc_p(z):
    return math.erfc(abs(z) / math.sqrt(2.0))


def chi2_z(chi2, df):
    # Wilson-Hilferty transform: good enough for quick screening.
    if df <= 0:
        return 0.0
    return (((chi2 / df) ** (1.0 / 3.0)) - (1.0 - 2.0 / (9.0 * df))) / math.sqrt(2.0 / (9.0 * df))


def bit_iter(data):
    for byte in data:
        for bit in range(8):
            yield (byte >> bit) & 1


def monobit(data):
    n = len(data) * 8
    ones = sum(int(x).bit_count() for x in data)
    zeros = n - ones
    s = ones - zeros
    z = s / math.sqrt(n)
    return ones, zeros, ones / n, z, erfc_p(z)


def runs_test(data):
    bits = list(bit_iter(data))
    n = len(bits)
    ones = sum(bits)
    pi = ones / n
    if abs(pi - 0.5) >= 2.0 / math.sqrt(n):
        return None
    runs = 1 + sum(1 for a, b in zip(bits, bits[1:]) if a != b)
    expected = 2.0 * n * pi * (1.0 - pi)
    denom = 2.0 * math.sqrt(2.0 * n) * pi * (1.0 - pi)
    z = (runs - expected) / denom
    return runs, expected, z, erfc_p(z)


def byte_chi2(data):
    counts = collections.Counter(data)
    n = len(data)
    expected = n / 256.0
    chi2 = sum(((counts.get(i, 0) - expected) ** 2) / expected for i in range(256))
    z = chi2_z(chi2, 255)
    return chi2, z, erfc_p(z)


def nibble_poker(data):
    counts = [0] * 16
    for byte in data:
        counts[byte & 0x0f] += 1
        counts[(byte >> 4) & 0x0f] += 1
    n = len(data) * 2
    expected = n / 16.0
    chi2 = sum(((count - expected) ** 2) / expected for count in counts)
    z = chi2_z(chi2, 15)
    return chi2, z, erfc_p(z)


def serial_corr(data):
    if len(data) < 2:
        return 0.0
    xs = data[:-1]
    ys = data[1:]
    mean_x = sum(xs) / len(xs)
    mean_y = sum(ys) / len(ys)
    cov = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    var_x = sum((x - mean_x) ** 2 for x in xs)
    var_y = sum((y - mean_y) ** 2 for y in ys)
    return cov / math.sqrt(var_x * var_y) if var_x and var_y else 0.0


def max_run(data):
    longest = 0
    current = 0
    last = None
    for bit in bit_iter(data):
        if bit == last:
            current += 1
        else:
            current = 1
            last = bit
        if current > longest:
            longest = current
    return longest


def min_entropy_mcv(data):
    counts = collections.Counter(data)
    pmax = max(counts.values()) / len(data)
    return -math.log2(pmax)


def verdict_p(p):
    if p < 1e-6 or p > 1.0 - 1e-6:
        return "FAIL"
    if p < 1e-3 or p > 1.0 - 1e-3:
        return "WARN"
    return "PASS"


def main():
    parser = argparse.ArgumentParser(description="Quick small-sample TRNG screening tests.")
    parser.add_argument("file", help="Binary random data file")
    args = parser.parse_args()

    data = open(args.file, "rb").read()
    if len(data) < 1024:
        raise SystemExit("need at least 1024 bytes")

    print(f"file: {os.path.abspath(args.file)}")
    print(f"bytes: {len(data)}")
    print(f"bits: {len(data) * 8}")

    ones, zeros, ratio, z, p = monobit(data)
    print(f"monobit: {verdict_p(p)} ones={ones} zeros={zeros} ratio={ratio:.8f} z={z:.4f} p~={p:.6g}")

    runs = runs_test(data)
    if runs is None:
        print("runs: FAIL skipped because monobit bias is too high")
    else:
        run_count, expected, z, p = runs
        print(f"runs: {verdict_p(p)} runs={run_count} expected={expected:.1f} z={z:.4f} p~={p:.6g}")

    chi2, z, p = byte_chi2(data)
    print(f"byte_chi2: {verdict_p(p)} chi2={chi2:.3f} df=255 z~={z:.4f} p~={p:.6g}")

    chi2, z, p = nibble_poker(data)
    print(f"nibble_poker: {verdict_p(p)} chi2={chi2:.3f} df=15 z~={z:.4f} p~={p:.6g}")

    corr = serial_corr(data)
    corr_status = "PASS" if abs(corr) < 0.002 else "WARN" if abs(corr) < 0.01 else "FAIL"
    print(f"serial_corr: {corr_status} r={corr:.8f}")

    longest = max_run(data)
    print(f"max_bit_run: INFO longest={longest}")
    print(f"min_entropy_mcv_per_byte: INFO h={min_entropy_mcv(data):.8f}")


if __name__ == "__main__":
    main()
