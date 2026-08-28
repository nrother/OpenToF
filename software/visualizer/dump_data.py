import serial
import struct

PORT = "/dev/ttyACM0"
BAUD = 921600

PACKET_SIZE = 12
ACCEL_SCALE = 0.061 * (16 >> 1) / 1000;
GYRO_SCALE = 4.375 * (2000 / 125) / 1000;

ser = serial.Serial(PORT, BAUD, timeout=0)
# reset board to sync
ser.write(b"r")
ser.reset_input_buffer()

print("gx,gy,gz,ax,ay,az")
while True:
    while ser.in_waiting >= PACKET_SIZE:

        packet = ser.read(PACKET_SIZE)

        if len(packet) != PACKET_SIZE:
            break

        # gx gy gz ax ay az
        gx, gy, gz, ax, ay, az = struct.unpack("<6h",packet)

        # Convert raw integer values to physical units.
        gx = gx * GYRO_SCALE
        gy = gy * GYRO_SCALE
        gz = gz * GYRO_SCALE

        ax = ax * ACCEL_SCALE
        ay = ay * ACCEL_SCALE
        az = az * ACCEL_SCALE

        print(f"{gx:.3f},{gy:.3f},{gz:.3f},{ax:.3f},{ay:.3f},{az:.3f}")
