#!/usr/bin/env python3
import argparse
import collections
import math
import os
import select
import subprocess
import sys
import termios
import time


class RawSerial:
    def __init__(self, port, baud, timeout=2):
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
        attrs[6][termios.VTIME] = int(self.timeout * 10)
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)

    def reset_input_buffer(self):
        termios.tcflush(self.fd, termios.TCIFLUSH)

    def read(self, size):
        ready, _, _ = select.select([self.fd], [], [], self.timeout)
        if not ready:
            return b""
        return os.read(self.fd, size)


def open_serial(port, baud):
    try:
        import serial
        return serial.Serial(port, baud, timeout=2, rtscts=False, dsrdtr=False, xonxoff=False)
    except ImportError:
        return RawSerial(port, baud, timeout=2)


def analyze(data):
    if not data:
        return {}

    nbytes = len(data)
    nbits = nbytes * 8
    ones = sum(int(byte).bit_count() for byte in data)
    zeros = nbits - ones

    counts = collections.Counter(data)
    expected = nbytes / 256.0
    chi2 = sum(((counts.get(i, 0) - expected) ** 2) / expected for i in range(256)) if expected else 0.0
    pmax = max(counts.values()) / nbytes
    min_entropy_per_byte = -math.log2(pmax) if pmax > 0.0 else 0.0

    if nbytes > 1:
        xs = list(data[:-1])
        ys = list(data[1:])
        mean_x = sum(xs) / len(xs)
        mean_y = sum(ys) / len(ys)
        cov = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
        var_x = sum((x - mean_x) ** 2 for x in xs)
        var_y = sum((y - mean_y) ** 2 for y in ys)
        serial_corr = cov / math.sqrt(var_x * var_y) if var_x and var_y else 0.0
    else:
        serial_corr = 0.0

    return {
        "bytes": nbytes,
        "bits": nbits,
        "ones": ones,
        "zeros": zeros,
        "one_ratio": ones / nbits,
        "byte_chi2_255df": chi2,
        "min_entropy_per_byte_mcv": min_entropy_per_byte,
        "serial_correlation_bytes": serial_corr,
    }


def print_stats(stats):
    for key, value in stats.items():
        if isinstance(value, float):
            print(f"{key}: {value:.8f}")
        else:
            print(f"{key}: {value}")


def run_dieharder(path):
    if subprocess.call(["bash", "-lc", "command -v dieharder >/dev/null 2>&1"]) != 0:
        print("dieharder not found; install it or run NIST/SP800-90B tools separately.")
        return
    subprocess.run(["dieharder", "-g", "201", "-f", path, "-a"], check=False)


def main():
    parser = argparse.ArgumentParser(description="Capture TRNG UART bytes and print basic statistics.")
    parser.add_argument("--port", required=True, help="Serial device, for example /dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=2000000, help="UART baud rate")
    parser.add_argument("--bytes", type=int, default=1048576, help="Number of bytes to capture")
    parser.add_argument("--out", default="trng_capture.bin", help="Output binary file")
    parser.add_argument("--dieharder", action="store_true", help="Run dieharder after capture if available")
    args = parser.parse_args()

    ser = open_serial(args.port, args.baud)
    ser.reset_input_buffer()

    remaining = args.bytes
    captured = bytearray()
    start = time.time()

    with open(args.out, "wb") as f:
        while remaining > 0:
            chunk = ser.read(min(65536, remaining))
            if not chunk:
                print("timeout while reading UART; check reset, bitstream, baud rate, and health_fail", file=sys.stderr)
                break
            f.write(chunk)
            captured.extend(chunk)
            remaining -= len(chunk)
            print(f"\r{len(captured)}/{args.bytes} bytes", end="", flush=True)

    elapsed = time.time() - start
    print()
    print(f"wrote: {os.path.abspath(args.out)}")
    print(f"rate_Bps: {len(captured) / elapsed:.2f}" if elapsed > 0 else "rate_Bps: inf")
    print_stats(analyze(captured))

    if args.dieharder:
        run_dieharder(args.out)


if __name__ == "__main__":
    main()
