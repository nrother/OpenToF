import argparse
import serial
import struct
import sys
import time

BAUD = 921600

MARKER = b"\xAA\x55"

# AA 55
# uint16 packetCounter
# uint16 debugData
# 6x int16 IMU data
PACKET_FORMAT = "<2sHH6h"
PACKET_SIZE = struct.calcsize(PACKET_FORMAT)  # 18 bytes

ACCEL_SCALE = 0.061 * (16 >> 1) / 1000
GYRO_SCALE = 4.375 * (2000 / 125) / 1000

parser = argparse.ArgumentParser(
    description="Read data from the datalogger firmware and dump it to stdout in CSV format"
)
parser.add_argument(
    "-p", "--port", default="/dev/ttyACM0",
    help="Serial port the sensor is connected to (default: %(default)s)",
)
args = parser.parse_args()

ser = serial.Serial(args.port, BAUD, timeout=0)

# Reset board to sync
ser.write(b"r")
ser.reset_input_buffer()

start_time = time.monotonic()
first_packet_counter = None

buffer = bytearray()
last_counter = None

print("counter,debugdata,gx,gy,gz,ax,ay,az")

try:
    while True:
        # Read whatever is currently available.
        n = ser.in_waiting

        if n:
            buffer.extend(ser.read(n))
        else:
            time.sleep(0.0005)
            continue

        while True:
            # Find beginning of a packet.
            marker_pos = buffer.find(MARKER)

            if marker_pos < 0:
                # No complete marker found.
                break

            if marker_pos > 0:
                # Throw away garbage / partial packet before marker.
                print(
                    f"Warning: discarded {marker_pos} byte(s) while resynchronizing",
                    file=sys.stderr,
                )
                del buffer[:marker_pos]

            # Marker is now at buffer[0].
            # Wait until the entire packet has arrived.
            if len(buffer) < PACKET_SIZE:
                break

            packet = buffer[:PACKET_SIZE]
            del buffer[:PACKET_SIZE]

            marker, counter, debugdata, gx, gy, gz, ax, ay, az = struct.unpack(
                PACKET_FORMAT, packet
            )

            # Detect dropped packets.
            if last_counter is not None:
                expected = (last_counter + 1) & 0xFFFF

                if counter != expected:
                    # modulo arithmetic also handles the
                    # uint16 rollover 65535 -> 0
                    missed = (counter - expected) & 0xFFFF

                    print(
                        f"Warning: packet loss: "
                        f"expected {expected}, got {counter}, "
                        f"missed {missed} packet(s)",
                        file=sys.stderr,
                    )

            last_counter = counter
            if first_packet_counter is None:
                first_packet_counter = counter

            # Convert raw integer values to physical units.
            gx *= GYRO_SCALE
            gy *= GYRO_SCALE
            gz *= GYRO_SCALE

            ax *= ACCEL_SCALE
            ay *= ACCEL_SCALE
            az *= ACCEL_SCALE

            print(
                f"{counter},",
                f"{debugdata},"
                f"{gx:.3f},{gy:.3f},{gz:.3f},"
                f"{ax:.3f},{ay:.3f},{az:.3f}"
            )
except KeyboardInterrupt:
    stop_time = time.monotonic()
    # reset board again for another sync point
    ser.write(b"r")
    
    # calculate the sensor data rate
    duration = stop_time -  start_time - 0.1 # subtract 100ms because this is the LED blink duration
    packet_count = (last_counter - first_packet_counter) & 0xFFFF # 16-bit unsigned, take into account overflows
    print(f"Got {packet_count} packets in {duration:.2f} s. Sensor data rate is {packet_count/duration:.2f} Hz", file=sys.stderr)
