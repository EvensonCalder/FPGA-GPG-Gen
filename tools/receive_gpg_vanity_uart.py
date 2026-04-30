#!/usr/bin/env python3
import argparse
import binascii
import ctypes
import os
import select
import stat
import struct
import sys
import termios
import time

from gpg_vanity_patterns import classify_fingerprint
from openpgp_ed25519 import openpgp_v4_ed25519_fingerprint, openpgp_v4_ed25519_secret_key_packet, public_from_seed


MAGIC = b"GPGV1"
SEED_LEN = 32
PUBLIC_LEN = 32
BODY_LEN = 1 + SEED_LEN + PUBLIC_LEN
CRC_LEN = 4
FRAME_LEN = len(MAGIC) + BODY_LEN + CRC_LEN
CLASS_COUNT = 2
CLASS_NAMES = ("suffix", "prefix")
HEARTBEAT_CLASS = 0xFE
HEARTBEAT_SHORT_BODY_LEN = 1 + 8 + 8
HEARTBEAT_SHORT_FRAME_LEN = len(MAGIC) + HEARTBEAT_SHORT_BODY_LEN + CRC_LEN


class RawSerial:
    def __init__(self, port, baud, timeout=2.0):
        self.timeout = timeout
        self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY)
        self._configure(baud)

    def _configure(self, baud):
        speed_name = f"B{baud}"
        if not hasattr(termios, speed_name):
            raise RuntimeError(f"termios does not support baud rate {baud}; install pyserial")
        speed = getattr(termios, speed_name)
        attrs = termios.tcgetattr(self.fd)
        attrs[0] = 0
        attrs[1] = 0
        attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
        if hasattr(termios, "CRTSCTS"):
            attrs[2] &= ~termios.CRTSCTS
        attrs[3] = 0
        attrs[4] = speed
        attrs[5] = speed
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = int(timeout_to_vtime(self.timeout))
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)

    def reset_input_buffer(self):
        termios.tcflush(self.fd, termios.TCIFLUSH)

    def read(self, size):
        ready, _, _ = select.select([self.fd], [], [], self.timeout)
        if not ready:
            return b""
        return os.read(self.fd, size)

    def close(self):
        os.close(self.fd)


def timeout_to_vtime(timeout):
    return max(1, min(255, int(timeout * 10)))


def open_serial(port, baud, timeout):
    try:
        import serial
        return serial.Serial(port, baud, timeout=timeout, rtscts=False, dsrdtr=False, xonxoff=False)
    except ImportError:
        return RawSerial(port, baud, timeout=timeout)


def disable_core_dumps():
    try:
        import resource
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    except Exception:
        pass


def try_mlockall():
    try:
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        if libc.mlockall(1 | 2) != 0:
            return os.strerror(ctypes.get_errno())
        return None
    except Exception as exc:
        return str(exc)


def prepare_output_dir(path):
    old_umask = os.umask(0o077)
    try:
        if os.path.exists(path):
            st = os.lstat(path)
            if stat.S_ISLNK(st.st_mode):
                raise RuntimeError(f"output directory is a symlink: {path}")
            if not stat.S_ISDIR(st.st_mode):
                raise RuntimeError(f"output path is not a directory: {path}")
            os.chmod(path, 0o700)
        else:
            os.makedirs(path, mode=0o700)
    finally:
        os.umask(old_umask)


def open_output_files(out_dir, prefix):
    files = []
    for class_id in range(CLASS_COUNT):
        path = os.path.join(out_dir, f"{prefix}_{CLASS_NAMES[class_id]}.txt")
        if os.path.exists(path) and stat.S_ISLNK(os.lstat(path).st_mode):
            raise RuntimeError(f"refusing to write through symlink: {path}")
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        os.fchmod(fd, 0o600)
        files.append(os.fdopen(fd, "a", buffering=1))
    return files


def close_output_files(files):
    for f in files:
        f.close()


def make_frame(class_id, seed_hex, public_hex):
    seed = bytes.fromhex(seed_hex)
    public = bytes.fromhex(public_hex)
    if not 0 <= class_id < CLASS_COUNT:
        raise ValueError("class id must be 0 or 1")
    if len(seed) != SEED_LEN:
        raise ValueError("seed must be 32 bytes")
    if len(public) != PUBLIC_LEN:
        raise ValueError("public key must be 32 bytes")
    body = bytes([class_id]) + seed + public
    crc = struct.pack("<I", binascii.crc32(body) & 0xffffffff)
    return MAGIC + body + crc


def parse_frames(buffer):
    records = []
    heartbeats = []
    bad_crc = 0

    while True:
        idx = buffer.find(MAGIC)
        if idx < 0:
            keep = max(0, len(MAGIC) - 1)
            if len(buffer) > keep:
                del buffer[:-keep]
            break
        if idx > 0:
            del buffer[:idx]
        if len(buffer) < HEARTBEAT_SHORT_FRAME_LEN:
            break
        class_id = buffer[len(MAGIC)]
        if class_id == HEARTBEAT_CLASS:
            body = bytes(buffer[len(MAGIC):len(MAGIC) + HEARTBEAT_SHORT_BODY_LEN])
            expected_crc = struct.unpack("<I", buffer[len(MAGIC) + HEARTBEAT_SHORT_BODY_LEN:HEARTBEAT_SHORT_FRAME_LEN])[0]
            actual_crc = binascii.crc32(body) & 0xffffffff
            if actual_crc == expected_crc:
                del buffer[:HEARTBEAT_SHORT_FRAME_LEN]
                produced_count = int.from_bytes(body[1:9], byteorder="big")
                accepted_count = int.from_bytes(body[9:17], byteorder="big")
                heartbeats.append((produced_count, accepted_count, 0, 0))
                continue
            if len(buffer) < FRAME_LEN:
                break
        elif len(buffer) < FRAME_LEN:
            break

        frame = bytes(buffer[:FRAME_LEN])
        body = frame[len(MAGIC):len(MAGIC) + BODY_LEN]
        class_id = body[0]
        if class_id == HEARTBEAT_CLASS:
            expected_crc = struct.unpack("<I", frame[-CRC_LEN:])[0]
            actual_crc = binascii.crc32(body) & 0xffffffff
            del buffer[:FRAME_LEN]
            if actual_crc != expected_crc:
                bad_crc += 1
                continue
            produced_count = int.from_bytes(body[1:9], byteorder="big")
            accepted_count = int.from_bytes(body[9:17], byteorder="big")
            stall_seed = int.from_bytes(body[17:25], byteorder="big")
            stall_output = int.from_bytes(body[25:33], byteorder="big")
            heartbeats.append((produced_count, accepted_count, stall_seed, stall_output))
            continue
        expected_crc = struct.unpack("<I", frame[-CRC_LEN:])[0]
        actual_crc = binascii.crc32(body) & 0xffffffff
        if actual_crc != expected_crc:
            del buffer[0]
            bad_crc += 1
            continue
        del buffer[:FRAME_LEN]
        if class_id >= CLASS_COUNT:
            bad_crc += 1
            continue
        seed = body[1:1 + SEED_LEN]
        public = body[1 + SEED_LEN:1 + SEED_LEN + PUBLIC_LEN]
        records.append((class_id, seed, public))

    return records, bad_crc, heartbeats


def write_openpgp_secret_file(out_dir, class_id, seed, public, timestamp, sync):
    class_name = CLASS_NAMES[class_id]
    keyid = f"{class_name}_{public.hex()[:16]}_{seed.hex()[:16]}"
    path = os.path.join(out_dir, f"{keyid}.gpg")
    if os.path.exists(path) and stat.S_ISLNK(os.lstat(path).st_mode):
        raise RuntimeError(f"refusing to write through symlink: {path}")
    packet = openpgp_v4_ed25519_secret_key_packet(seed, public, timestamp)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = os.open(path, flags, 0o600)
    try:
        os.write(fd, packet)
        if sync:
            os.fsync(fd)
    finally:
        os.close(fd)
    return path


def write_record(files, class_id, seed, public, sync, *, gpg_dir=None, timestamp=None):
    line = f"{CLASS_NAMES[class_id]} {seed.hex()} {public.hex()}\n"
    f = files[class_id]
    f.write(line)
    if sync:
        f.flush()
        os.fsync(f.fileno())
    if gpg_dir is not None:
        write_openpgp_secret_file(gpg_dir, class_id, seed, public, timestamp, sync)


def verify_hit_record(class_id, seed, public, timestamp, verify_seed):
    if verify_seed and public_from_seed(seed) != public:
        return False, "seed does not derive public key"
    fingerprint = openpgp_v4_ed25519_fingerprint(public, timestamp).hex().upper()
    hit_classes = {hit[0] for hit in classify_fingerprint(fingerprint)}
    if class_id not in hit_classes:
        return False, f"fingerprint {fingerprint} does not match class {CLASS_NAMES[class_id]}"
    return True, fingerprint


def receive(args):
    disable_core_dumps()
    if args.mlock:
        err = try_mlockall()
        if err and not args.quiet:
            print(f"warning: mlockall unavailable: {err}", file=sys.stderr)

    prepare_output_dir(args.out_dir)
    if args.gpg_dir:
        prepare_output_dir(args.gpg_dir)
    files = open_output_files(args.out_dir, args.file_prefix)
    source = None
    total = 0
    bad_crc = 0
    buffer = bytearray()
    last_report = time.monotonic()
    last_report_total = 0
    last_hb = None

    try:
        if args.input_bin:
            source = open(args.input_bin, "rb")
        else:
            source = open_serial(args.port, args.baud, args.timeout)
            source.reset_input_buffer()

        while args.max_records is None or total < args.max_records:
            chunk = source.read(args.read_size)
            if not chunk:
                if args.input_bin:
                    break
                now = time.monotonic()
                if not args.quiet and now - last_report >= args.report_interval:
                    elapsed = now - last_report
                    window_total = total - last_report_total
                    print(f"rate hits/s={window_total / elapsed:.3f} keys/s=N/A accepted={total} bad_crc={bad_crc}",
                          file=sys.stderr, flush=True)
                    last_report = now
                    last_report_total = total
                continue

            buffer.extend(chunk)
            records, new_bad_crc, heartbeats = parse_frames(buffer)
            bad_crc += new_bad_crc
            for produced_count, accepted_count, stall_seed, stall_output in heartbeats:
                now = time.monotonic()
                if last_hb is not None:
                    prev_time, prev_keys = last_hb
                    delta_t = now - prev_time
                    delta_k = produced_count - prev_keys
                    keys_per_s = delta_k / delta_t if delta_t > 0 else 0.0
                    if keys_per_s < 3000 or keys_per_s > 18000:
                        continue
                    if stall_output > (1 << 40) or accepted_count < produced_count - 100:
                        continue
                    if not args.quiet:
                        print(f"heartbeat keys={produced_count} rate={keys_per_s:.0f} keys/s "
                              f"accepted={accepted_count} stall_seed={stall_seed} stall_out={stall_output}",
                              file=sys.stderr, flush=True)
                last_hb = (now, produced_count)
                last_report = now
            for class_id, seed, public in records:
                if not args.no_verify_hit:
                    ok, detail = verify_hit_record(class_id, seed, public, args.timestamp, args.verify_seed)
                    if not ok:
                        bad_crc += 1
                        if not args.quiet:
                            print(f"rejected class={CLASS_NAMES[class_id]} reason={detail}", file=sys.stderr, flush=True)
                        continue
                write_record(files, class_id, seed, public, not args.no_fsync,
                             gpg_dir=args.gpg_dir, timestamp=args.timestamp)
                total += 1
                if not args.quiet:
                    print(f"accepted class={CLASS_NAMES[class_id]} total={total}", file=sys.stderr, flush=True)
                now = time.monotonic()
                if now - last_report >= args.report_interval:
                    elapsed = now - last_report
                    window_total = total - last_report_total
                    print(f"rate hits/s={window_total / elapsed:.3f} keys/s=N/A accepted={total} bad_crc={bad_crc}",
                          file=sys.stderr, flush=True)
                    last_report = now
                    last_report_total = total
                if args.max_records is not None and total >= args.max_records:
                    break
    finally:
        if source is not None:
            source.close()
        close_output_files(files)

    if not args.quiet:
        print(f"done; accepted={total} bad_crc={bad_crc} out_dir={os.path.abspath(args.out_dir)}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Receive FPGA GPG vanity Ed25519 hits and split them into two private output files."
    )
    parser.add_argument("--port", default="/dev/ttyUSB1", help="serial device")
    parser.add_argument("--baud", type=int, default=2000000, help="UART baud rate")
    parser.add_argument("--timeout", type=float, default=2.0, help="serial read timeout in seconds")
    parser.add_argument("--out-dir", default="build/gpg_vanity_hits", help="private output directory")
    parser.add_argument("--file-prefix", default="class", help="output filename prefix")
    parser.add_argument("--max-records", type=int, help="stop after this many accepted records")
    parser.add_argument("--read-size", type=int, default=4096, help="read chunk size")
    parser.add_argument("--report-interval", type=float, default=60.0, help="idle progress interval")
    parser.add_argument("--no-fsync", action="store_true", help="do not fsync after every accepted key")
    parser.add_argument("--gpg-dir", help="also write each hit as a private OpenPGP .gpg secret-key packet")
    parser.add_argument("--timestamp", type=lambda x: int(x, 0), default=1700000000,
                        help="OpenPGP creation timestamp for --gpg-dir output")
    parser.add_argument("--mlock", action="store_true", help="try to lock process memory")
    parser.add_argument("--no-verify-hit", action="store_true",
                        help="do not recompute fingerprint/pattern before writing hits")
    parser.add_argument("--verify-seed", action="store_true",
                        help="also derive public key from seed before writing hits; requires cryptography")
    parser.add_argument("--quiet", action="store_true", help="suppress progress messages")
    parser.add_argument("--input-bin", help="read frames from a binary file instead of UART, for tests")
    parser.add_argument("--make-test-frame", nargs=3, metavar=("CLASS", "SEED_HEX", "PUBLIC_HEX"),
                        help="write one encoded frame to stdout and exit")
    args = parser.parse_args()

    if args.make_test_frame:
        class_id = int(args.make_test_frame[0], 0)
        frame = make_frame(class_id, args.make_test_frame[1], args.make_test_frame[2])
        sys.stdout.buffer.write(frame)
        return

    if not args.input_bin and not args.port:
        parser.error("--port is required unless --input-bin is used")

    receive(args)


if __name__ == "__main__":
    main()
