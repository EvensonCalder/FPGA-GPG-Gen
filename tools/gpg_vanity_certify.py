#!/usr/bin/env python3
import argparse
import hashlib
import os
import subprocess
import sys
import tempfile

from cryptography.hazmat.primitives.asymmetric import ed25519

from openpgp_ed25519 import (
    ED25519_OID,
    PUBKEY_ALGO_EDDSA,
    mpi_from_opaque,
    mpi_from_ed25519_secret_seed,
    openpgp_new_packet,
    openpgp_v4_ed25519_public_body,
    openpgp_v4_ed25519_secret_body,
    openpgp_v4_fingerprint_from_body,
    parse_new_packet_header,
    public_from_seed,
)


PREF_SYM = bytes([9, 8, 7, 2])
PREF_HASH = bytes([10, 9, 8, 11, 2])
PREF_ZIP = bytes([2, 3, 1])


def read_packet(path):
    data = open(path, "rb").read()
    tag, body_offset, length = parse_new_packet_header(data, 0)
    body = data[body_offset:body_offset + length]
    if tag != 5:
        raise ValueError(f"{path}: expected secret-key packet tag 5, got {tag}")
    if len(body) != length or body_offset + length != len(data):
        raise ValueError(f"{path}: expected exactly one complete secret-key packet")
    return body


def parse_mpi(body, offset):
    if offset + 2 > len(body):
        raise ValueError("truncated MPI")
    bits = int.from_bytes(body[offset:offset + 2], "big")
    size = (bits + 7) // 8
    offset += 2
    value = body[offset:offset + size]
    if len(value) != size:
        raise ValueError("truncated MPI value")
    return bits, value, offset + size


def parse_secret_seed_mpi(body, offset):
    if offset + 4 > len(body):
        raise ValueError("truncated secret MPI")
    bits = int.from_bytes(body[offset:offset + 2], "big")
    min_size = (bits + 7) // 8
    value_start = offset + 2
    checksum = body[-2:]
    value = body[value_start:-2]
    if len(value) < min_size:
        raise ValueError("truncated secret MPI value")
    return bits, value, checksum


def parse_bare_secret_packet(path):
    body = read_packet(path)
    if len(body) < 6 or body[0] != 4:
        raise ValueError(f"{path}: expected OpenPGP v4 secret key")
    timestamp = int.from_bytes(body[1:5], "big")
    algo = body[5]
    if algo != PUBKEY_ALGO_EDDSA:
        raise ValueError(f"{path}: expected EdDSA algo 22, got {algo}")
    offset = 6
    oid_len = body[offset]
    offset += 1
    oid = body[offset:offset + oid_len]
    offset += oid_len
    if oid != ED25519_OID:
        raise ValueError(f"{path}: expected Ed25519 OID")
    _, point, offset = parse_mpi(body, offset)
    if len(point) != 33 or point[0] != 0x40:
        raise ValueError(f"{path}: invalid Ed25519 public point")
    public = point[1:]
    if body[offset] != 0:
        raise ValueError(f"{path}: encrypted secret keys are not supported")
    offset += 1
    _, seed, checksum = parse_secret_seed_mpi(body, offset)
    if len(seed) > 32:
        raise ValueError(f"{path}: expected Ed25519 seed no longer than 32 bytes")
    seed = seed.rjust(32, b"\x00")
    expected_checksums = {
        (sum(mpi_from_ed25519_secret_seed(seed)) & 0xffff).to_bytes(2, "big"),
        (sum(mpi_from_opaque(seed)) & 0xffff).to_bytes(2, "big"),
    }
    if checksum not in expected_checksums:
        raise ValueError(f"{path}: secret checksum mismatch")
    derived = public_from_seed(seed)
    if derived != public:
        raise ValueError(f"{path}: seed does not derive packet public key")
    public_body = openpgp_v4_ed25519_public_body(public, timestamp)
    fingerprint = openpgp_v4_fingerprint_from_body(public_body)
    return timestamp, seed, public, fingerprint


def subpacket(subpacket_type, data):
    body = bytes([subpacket_type]) + data
    if len(body) >= 192:
        raise ValueError("large signature subpackets are not supported")
    return bytes([len(body)]) + body


def certification_signature(seed, public, timestamp, uid):
    public_body = openpgp_v4_ed25519_public_body(public, timestamp)
    fingerprint = openpgp_v4_fingerprint_from_body(public_body)
    keyid = fingerprint[-8:]

    hashed = b"".join([
        subpacket(33, b"\x04" + fingerprint),
        subpacket(2, timestamp.to_bytes(4, "big")),
        subpacket(27, b"\x03"),
        subpacket(11, PREF_SYM),
        subpacket(21, PREF_HASH),
        subpacket(22, PREF_ZIP),
        subpacket(30, b"\x07"),
        subpacket(23, b"\x80"),
    ])
    unhashed = subpacket(16, keyid)
    sig_head = bytes([4, 0x13, PUBKEY_ALGO_EDDSA, 10]) + len(hashed).to_bytes(2, "big") + hashed
    signed = (
        b"\x99" + len(public_body).to_bytes(2, "big") + public_body
        + b"\xb4" + len(uid).to_bytes(4, "big") + uid
    )
    trailer = b"\x04\xff" + len(sig_head).to_bytes(4, "big")
    digest = hashlib.sha512(signed + sig_head + trailer).digest()
    sig = ed25519.Ed25519PrivateKey.from_private_bytes(seed).sign(digest)
    body = (
        sig_head
        + len(unhashed).to_bytes(2, "big")
        + unhashed
        + digest[:2]
        + mpi_from_opaque(sig[:32])
        + mpi_from_opaque(sig[32:])
    )
    return openpgp_new_packet(2, body)


def transferable_secret_certificate(seed, public, timestamp, uid_text):
    uid = uid_text.encode("utf-8")
    return (
        openpgp_new_packet(5, openpgp_v4_ed25519_secret_body(seed, public, timestamp))
        + openpgp_new_packet(13, uid)
        + certification_signature(seed, public, timestamp, uid)
    )


def default_output_name(in_path, fingerprint):
    base = os.path.splitext(os.path.basename(in_path))[0]
    return f"{base}_{fingerprint.hex().upper()[-16:]}_transferable.gpg"


def run_gpg(args, gnupghome, *cmd, input_data=None):
    env = os.environ.copy()
    env["GNUPGHOME"] = gnupghome
    proc = subprocess.run(["gpg", "--batch", *cmd], input=input_data, env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode("utf-8", "replace").strip())
    return proc


def verify_transferable(path, fingerprint):
    with tempfile.TemporaryDirectory(prefix="gpggen_verify_") as tmp:
        os.chmod(tmp, 0o700)
        run_gpg(None, tmp, "--import", path)
        listed = run_gpg(None, tmp, "--with-colons", "--fingerprint", "--list-secret-keys").stdout.decode()
        if fingerprint.hex().upper() not in listed.upper().replace(":", ""):
            raise ValueError("imported secret key fingerprint was not found")
        msg = os.path.join(tmp, "message.txt")
        sig = os.path.join(tmp, "message.txt.asc")
        with open(msg, "w", encoding="utf-8") as f:
            f.write("GPGgen transferable certificate verification\n")
        run_gpg(None, tmp, "--yes", "--local-user", fingerprint.hex().upper(), "--armor", "--detach-sign", "--output", sig, msg)
        run_gpg(None, tmp, "--verify", sig, msg)


def command_info(args):
    for path in args.files:
        timestamp, seed, public, fingerprint = parse_bare_secret_packet(path)
        print(f"{path}\tfingerprint={fingerprint.hex().upper()}\tkeyid={fingerprint[-8:].hex().upper()}\ttimestamp={timestamp}\tpublic={public.hex()}")


def command_convert(args):
    os.makedirs(args.out_dir, mode=0o700, exist_ok=True)
    os.chmod(args.out_dir, 0o700)
    for path in args.files:
        timestamp, seed, public, fingerprint = parse_bare_secret_packet(path)
        cert = transferable_secret_certificate(seed, public, timestamp, args.uid)
        out_path = os.path.join(args.out_dir, default_output_name(path, fingerprint))
        flags = os.O_WRONLY | os.O_CREAT | (0 if args.overwrite else os.O_EXCL)
        if args.overwrite:
            flags |= os.O_TRUNC
        fd = os.open(out_path, flags, 0o600)
        try:
            os.write(fd, cert)
            os.fsync(fd)
        finally:
            os.close(fd)
        if args.verify:
            verify_transferable(out_path, fingerprint)
        print(f"WROTE {out_path} fingerprint={fingerprint.hex().upper()} keyid={fingerprint[-8:].hex().upper()}")


def main():
    parser = argparse.ArgumentParser(description="Inspect and convert GPGgen bare secret-key packets.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_info = sub.add_parser("info", help="print fingerprint/key metadata for bare .gpg packets")
    p_info.add_argument("files", nargs="+")
    p_info.set_defaults(func=command_info)

    p_convert = sub.add_parser("convert", help="write GnuPG-importable transferable secret certificates")
    p_convert.add_argument("files", nargs="+")
    p_convert.add_argument("--uid", required=True, help='user ID, e.g. "Name <email@example.com>"')
    p_convert.add_argument("--out-dir", required=True)
    p_convert.add_argument("--overwrite", action="store_true")
    p_convert.add_argument("--no-verify", dest="verify", action="store_false", help="skip temporary GnuPG import/sign/verify")
    p_convert.set_defaults(func=command_convert, verify=True)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
