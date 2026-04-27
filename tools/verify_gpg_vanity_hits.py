#!/usr/bin/env python3
import argparse
import os
import sys

from gpg_vanity_patterns import classify_fingerprint
from openpgp_ed25519 import openpgp_v4_ed25519_fingerprint, public_from_seed


CLASS_NAMES = ("suffix", "prefix")


def iter_hit_files(path, prefix):
    for class_id, name in enumerate(CLASS_NAMES):
        file_path = os.path.join(path, f"{prefix}_{name}.txt")
        if os.path.exists(file_path):
            yield class_id, file_path


def parse_line(line, file_path, line_no):
    fields = line.split()
    if len(fields) != 3:
        raise ValueError(f"{file_path}:{line_no}: expected 'class seed public'")
    class_id = CLASS_NAMES.index(fields[0]) if fields[0] in CLASS_NAMES else int(fields[0], 0)
    seed = bytes.fromhex(fields[1])
    public = bytes.fromhex(fields[2])
    if len(seed) != 32:
        raise ValueError(f"{file_path}:{line_no}: seed is not 32 bytes")
    if len(public) != 32:
        raise ValueError(f"{file_path}:{line_no}: public key is not 32 bytes")
    return class_id, seed, public


def verify(args):
    total = 0
    failures = 0

    for expected_file_class, file_path in iter_hit_files(args.hits_dir, args.file_prefix):
        with open(file_path, "r", encoding="ascii") as f:
            for line_no, raw_line in enumerate(f, 1):
                line = raw_line.strip()
                if not line:
                    continue
                total += 1
                try:
                    class_id, seed, public = parse_line(line, file_path, line_no)
                    if class_id != expected_file_class:
                        raise ValueError(f"record class {CLASS_NAMES[class_id]} is in class_{CLASS_NAMES[expected_file_class]}")

                    if args.verify_seed:
                        derived_public = public_from_seed(seed)
                        if derived_public != public:
                            raise ValueError("seed does not derive recorded public key")

                    fingerprint = openpgp_v4_ed25519_fingerprint(public, args.timestamp).hex().upper()
                    hit_classes = {hit[0] for hit in classify_fingerprint(fingerprint)}
                    if class_id not in hit_classes:
                        raise ValueError(f"fingerprint {fingerprint} does not match class {CLASS_NAMES[class_id]}")
                except Exception as exc:
                    failures += 1
                    print(f"FAIL {file_path}:{line_no}: {exc}", file=sys.stderr)
                    if args.stop_on_fail:
                        return 1

    if failures:
        print(f"FAIL verified={total} failures={failures}", file=sys.stderr)
        return 1
    print(f"PASS verified={total} failures=0")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Verify received GPG vanity hit files.")
    parser.add_argument("hits_dir", help="directory containing class_suffix.txt and/or class_prefix.txt")
    parser.add_argument("--timestamp", type=lambda x: int(x, 0), required=True,
                        help="OpenPGP creation timestamp used by the FPGA")
    parser.add_argument("--file-prefix", default="class", help="hit file prefix")
    parser.add_argument("--verify-seed", action="store_true",
                        help="also derive the Ed25519 public key from each seed; requires cryptography")
    parser.add_argument("--stop-on-fail", action="store_true", help="stop after the first bad record")
    args = parser.parse_args()
    sys.exit(verify(args))


if __name__ == "__main__":
    main()
