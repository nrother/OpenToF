# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "pandas",
#     "pyserial",
# ]
# ///

import argparse
import struct
import sys
import time
from pathlib import Path

import pandas as pd
import serial

BAUD = 115200
DEFAULT_SAMPLE_RATE = 416.0
SAMPLE_FORMAT = "<6h"
SAMPLE_SIZE = struct.calcsize(SAMPLE_FORMAT)
AXES = ("gx", "gy", "gz", "ax", "ay", "az")
ACCEL_SCALE = 0.061 * 8 / 1000
GYRO_SCALE = 0.07

parser = argparse.ArgumentParser(
    description="Replay recorded IMU CSV samples to OpenToF firmware over Serial"
)
parser.add_argument("input", nargs="?", default="-", type=Path, help="CSV file produced by dump_data.py or the datalogger (default: stdin)")
parser.add_argument(
    "-p", "--port", default="/dev/ttyACM0",
    help="Serial port the sensor is connected to (default: %(default)s)",
)
parser.add_argument(
    "--rate", type=float, default=DEFAULT_SAMPLE_RATE, 
    help="Sample transmission rate in Hz (default: %(default)s)",
)
args = parser.parse_args()

csv_source = sys.stdin if args.input == Path("-") else args.input
samples = pd.read_csv(csv_source, usecols=AXES)
scales = (GYRO_SCALE,) * 3 + (ACCEL_SCALE,) * 3
# convert to IMU representation
raw_samples = (samples[list(AXES)].div(pd.Series(scales, index=AXES), axis="columns").round().astype("int16"))

total_packets = 0

with serial.Serial(args.port, BAUD, write_timeout=5) as port:
    # Opening the port may reset the board; leave its startup messages queued.
    time.sleep(2)
    startup_output = port.read(port.in_waiting)
    if startup_output:
        sys.stdout.write(startup_output.decode("utf-8", errors="replace"))
        sys.stdout.flush()
    start_time = time.perf_counter()

    for count, values in enumerate(raw_samples.itertuples(index=False, name=None), start=1):
        deadline = start_time + (count - 1) / args.rate
        remaining = deadline - time.perf_counter()
        if remaining > 0:
            time.sleep(remaining)

        sample = struct.pack(SAMPLE_FORMAT, *values)
        if len(sample) != SAMPLE_SIZE:
            raise RuntimeError("Unexpected IMU sample size")
        port.write(sample)
        # The firmware writes its heartbeat and startup diagnostics to this port.
        waiting = port.in_waiting
        if waiting:
            output = port.read(waiting)
            sys.stdout.write(output.decode("utf-8", errors="replace"))
            sys.stdout.flush()

        total_packets += 1
        if total_packets % 100 == 0:
            print(f".", file=sys.stderr, end="", flush=True)

    port.flush()

print(f"\nSent {len(raw_samples)} IMU samples.", file=sys.stderr)
