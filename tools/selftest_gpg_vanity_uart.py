#!/usr/bin/env python3
import argparse
import binascii
import os
import shutil
import subprocess
import struct
import tempfile


def run(cmd, *, input_data=None, cwd=None):
    return subprocess.run(cmd, input=input_data, cwd=cwd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def make_heartbeat(produced, accepted, stall_seed, stall_output):
    body = (
        bytes([0xFE])
        + produced.to_bytes(8, "big")
        + accepted.to_bytes(8, "big")
        + stall_seed.to_bytes(8, "big")
        + stall_output.to_bytes(8, "big")
        + bytes(32)
    )
    crc = struct.pack("<I", binascii.crc32(body) & 0xffffffff)
    return b"GPGV1" + body + crc


def main():
    parser = argparse.ArgumentParser(description="Self-test the GPG vanity UART frame receiver with synthetic frames.")
    parser.add_argument("--keep", action="store_true", help="keep the temporary output directory")
    args = parser.parse_args()

    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    receiver = os.path.join(repo, "tools", "receive_gpg_vanity_uart.py")
    tmp = tempfile.mkdtemp(prefix="gpg_vanity_uart_selftest_")
    frame_path = os.path.join(tmp, "frames.bin")
    out_dir = os.path.join(tmp, "hits")

    seed0 = bytes(range(32)).hex()
    public0 = bytes(range(0x80, 0xa0)).hex()
    seed1 = bytes(range(0x20, 0x40)).hex()
    public1 = bytes(range(0xa0, 0xc0)).hex()

    try:
        frame0 = run([receiver, "--make-test-frame", "0", seed0, public0], cwd=repo).stdout
        frame1 = run([receiver, "--make-test-frame", "1", seed1, public1], cwd=repo).stdout
        with open(frame_path, "wb") as f:
            f.write(b"noise")
            f.write(make_heartbeat(1000, 1000, 5, 0))
            f.write(frame0)
            f.write(b"more-noise")
            f.write(make_heartbeat(10000, 10000, 10, 0))
            f.write(frame1)

        run([receiver, "--input-bin", frame_path, "--out-dir", out_dir, "--max-records", "2", "--quiet"], cwd=repo)

        with open(os.path.join(out_dir, "class_suffix.txt"), "r", encoding="ascii") as f:
            line0 = f.read().strip()
        with open(os.path.join(out_dir, "class_prefix.txt"), "r", encoding="ascii") as f:
            line1 = f.read().strip()

        expected0 = f"suffix {seed0} {public0}"
        expected1 = f"prefix {seed1} {public1}"
        if line0 != expected0:
            raise RuntimeError(f"class_suffix mismatch: {line0!r} != {expected0!r}")
        if line1 != expected1:
            raise RuntimeError(f"class_prefix mismatch: {line1!r} != {expected1!r}")

        print("PASS selftest_gpg_vanity_uart")
        if args.keep:
            print(out_dir)
    finally:
        if args.keep:
            return
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
