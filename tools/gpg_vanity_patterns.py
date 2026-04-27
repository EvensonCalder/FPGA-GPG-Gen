#!/usr/bin/env python3
import argparse


HEX_ALPHABET = "0123456789ABCDEF"


def same8(s):
    return len(s) == 8 and all(ch == s[0] for ch in s)


def classify_fingerprint(fingerprint_hex):
    fp = "".join(ch for ch in fingerprint_hex.upper() if ch in HEX_ALPHABET)
    if len(fp) < 8:
        raise ValueError("fingerprint must contain at least 8 hex digits")

    hits = []
    suffix = fp[-8:]
    prefix = fp[:8]
    if same8(suffix):
        hits.append((0, "suffix", "same8", suffix))
    if same8(prefix):
        hits.append((1, "prefix", "same8", prefix))
    return hits


def print_summary():
    print("0 suffix_same8 16")
    print("1 prefix_same8 16")
    print("prefix_plus_suffix_total 32")


def main():
    parser = argparse.ArgumentParser(description="Classify 8-hex same-nibble GPG vanity fingerprint patterns.")
    parser.add_argument("fingerprint", nargs="?", help="fingerprint hex to classify")
    parser.add_argument("--summary", action="store_true", help="print pattern-family counts")
    args = parser.parse_args()

    if args.summary:
        print_summary()

    if args.fingerprint:
        hits = classify_fingerprint(args.fingerprint)
        for class_id, side, name, matched in hits:
            print(f"{class_id:x} {side} {name} {matched}")
        if not hits:
            print("no_match")


if __name__ == "__main__":
    main()
