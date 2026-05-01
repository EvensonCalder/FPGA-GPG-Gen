#!/usr/bin/env python3
import argparse
import hashlib
import os
import struct
import sys
import time


ED25519_OID = bytes.fromhex("2b06010401da470f01")
PUBKEY_ALGO_EDDSA = 22


def clean_hex(s):
    return "".join(ch for ch in s if ch in "0123456789abcdefABCDEF")


def mpi_from_opaque(data):
    if not data:
        return b"\x00\x00"
    bit_len = (len(data) - 1) * 8 + data[0].bit_length()
    return bit_len.to_bytes(2, "big") + data


def mpi_from_fixed_opaque(data):
    if not data:
        return b"\x00\x00"
    return (len(data) * 8).to_bytes(2, "big") + data


def mpi_from_ed25519_secret_seed(seed):
    if len(seed) != 32:
        raise ValueError("Ed25519 seed must be 32 bytes")
    if seed[0] == 0:
        return mpi_from_fixed_opaque(seed)
    return mpi_from_opaque(seed)


def openpgp_v4_ed25519_public_body(public_key, timestamp):
    if len(public_key) != 32:
        raise ValueError("Ed25519 public key must be 32 bytes")
    if not 0 <= timestamp <= 0xffffffff:
        raise ValueError("timestamp must fit in 32 bits")

    # GnuPG v4 Ed25519 public keys use algorithm 22, the Ed25519 OID,
    # and an MPI containing 0x40 || the native 32-byte Ed25519 public key.
    point = b"\x40" + public_key
    return (
        b"\x04"
        + timestamp.to_bytes(4, "big")
        + bytes([PUBKEY_ALGO_EDDSA])
        + bytes([len(ED25519_OID)])
        + ED25519_OID
        + mpi_from_opaque(point)
    )


def openpgp_new_packet(tag, body):
    if not 0 <= tag <= 63:
        raise ValueError("packet tag must fit in new-format header")
    if len(body) < 192:
        length = bytes([len(body)])
    elif len(body) < 8384:
        n = len(body) - 192
        length = bytes([(n >> 8) + 192, n & 0xff])
    else:
        length = b"\xff" + len(body).to_bytes(4, "big")
    return bytes([0xc0 | tag]) + length + body


def openpgp_v4_ed25519_public_key_packet(public_key, timestamp):
    return openpgp_new_packet(6, openpgp_v4_ed25519_public_body(public_key, timestamp))


def openpgp_v4_ed25519_secret_body(seed, public_key, timestamp):
    if len(seed) != 32:
        raise ValueError("Ed25519 seed must be 32 bytes")
    public_body = openpgp_v4_ed25519_public_body(public_key, timestamp)
    secret_mpi = mpi_from_ed25519_secret_seed(seed)
    checksum = (sum(secret_mpi) & 0xffff).to_bytes(2, "big")
    return public_body + b"\x00" + secret_mpi + checksum


def openpgp_v4_ed25519_secret_key_packet(seed, public_key, timestamp):
    return openpgp_new_packet(5, openpgp_v4_ed25519_secret_body(seed, public_key, timestamp))


def openpgp_v4_fingerprint_from_body(body):
    if len(body) > 0xffff:
        raise ValueError("v4 public key packet body is too large")
    return hashlib.sha1(b"\x99" + len(body).to_bytes(2, "big") + body).digest()


def openpgp_v4_ed25519_fingerprint(public_key, timestamp):
    body = openpgp_v4_ed25519_public_body(public_key, timestamp)
    return openpgp_v4_fingerprint_from_body(body)


def public_from_seed(seed):
    if len(seed) != 32:
        raise ValueError("Ed25519 seed must be 32 bytes")
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization

    private_key = ed25519.Ed25519PrivateKey.from_private_bytes(seed)
    public_key = private_key.public_key()
    return public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )


def parse_new_packet_header(data, offset):
    first = data[offset]
    if first & 0x80 == 0:
        raise ValueError("not an OpenPGP packet")
    if first & 0x40 == 0:
        tag = (first >> 2) & 0x0f
        length_type = first & 0x03
        offset += 1
        if length_type == 0:
            length = data[offset]
            offset += 1
        elif length_type == 1:
            length = int.from_bytes(data[offset:offset + 2], "big")
            offset += 2
        elif length_type == 2:
            length = int.from_bytes(data[offset:offset + 4], "big")
            offset += 4
        else:
            raise ValueError("indeterminate old-format length is unsupported")
        return tag, offset, length

    tag = first & 0x3f
    offset += 1
    length_octet = data[offset]
    offset += 1
    if length_octet < 192:
        length = length_octet
    elif length_octet < 224:
        length = ((length_octet - 192) << 8) + data[offset] + 192
        offset += 1
    elif length_octet == 255:
        length = int.from_bytes(data[offset:offset + 4], "big")
        offset += 4
    else:
        raise ValueError("partial new-format length is unsupported")
    return tag, offset, length


def first_public_key_body(openpgp_binary):
    offset = 0
    while offset < len(openpgp_binary):
        tag, body_offset, length = parse_new_packet_header(openpgp_binary, offset)
        body = openpgp_binary[body_offset:body_offset + length]
        if len(body) != length:
            raise ValueError("truncated OpenPGP packet")
        if tag == 6:
            return body
        offset = body_offset + length
    raise ValueError("no public-key packet found")


def summarize(public_key, timestamp, seed=None):
    body = openpgp_v4_ed25519_public_body(public_key, timestamp)
    fingerprint = openpgp_v4_fingerprint_from_body(body)
    print(f"timestamp: {timestamp}")
    if seed is not None:
        print(f"seed: {seed.hex()}")
    print(f"public: {public_key.hex()}")
    print(f"packet_body: {body.hex()}")
    print(f"fingerprint: {fingerprint.hex().upper()}")
    print(f"keyid: {fingerprint[-8:].hex().upper()}")


def main():
    parser = argparse.ArgumentParser(description="OpenPGP v4 Ed25519 public-key fingerprint reference tool.")
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--seed", help="32-byte Ed25519 seed hex")
    src.add_argument("--public", help="32-byte Ed25519 public key hex")
    src.add_argument("--parse-public-export", help="binary GnuPG public-key export to parse and fingerprint")
    parser.add_argument("--timestamp", type=lambda x: int(x, 0), help="OpenPGP creation timestamp")
    parser.add_argument("--now", action="store_true", help="use current Unix timestamp")
    args = parser.parse_args()

    if args.parse_public_export:
        with open(args.parse_public_export, "rb") as f:
            body = first_public_key_body(f.read())
        fingerprint = openpgp_v4_fingerprint_from_body(body)
        print(f"packet_body: {body.hex()}")
        print(f"fingerprint: {fingerprint.hex().upper()}")
        print(f"keyid: {fingerprint[-8:].hex().upper()}")
        return

    if args.now:
        timestamp = int(time.time())
    elif args.timestamp is not None:
        timestamp = args.timestamp
    else:
        parser.error("--timestamp or --now is required for --seed/--public")

    seed = None
    if args.seed:
        seed = bytes.fromhex(clean_hex(args.seed))
        public_key = public_from_seed(seed)
    else:
        public_key = bytes.fromhex(clean_hex(args.public))

    summarize(public_key, timestamp, seed=seed)


if __name__ == "__main__":
    main()
