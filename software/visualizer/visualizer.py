# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "scipy",
#     "matplotlib",
#     "pyserial",
#     "AHRS",
#     "PyQt6",
# ]
# ///
import serial
import numpy as np
from ahrs.filters import Madgwick
import matplotlib
matplotlib.use("QtAgg")
import matplotlib.pyplot as plt
from scipy.spatial.transform import Rotation
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import time
import struct

PORT = "/dev/ttyACM0"
BAUD = 921600
RATE = 416
DISPLAY_HZ = 60

PACKET_SIZE = 12
ACCEL_SCALE = 0.061 * (16 >> 1) / 1000;
GYRO_SCALE = 4.375 * (2000 / 125) / 1000;

ser = serial.Serial(PORT, BAUD, timeout=0)
# reset board to sync
ser.write(b"r")
ser.reset_input_buffer()

madgwick = Madgwick(frequency=RATE)
q = np.array([1., 0., 0., 0.])

# Cube
v = np.array([
    [-1,-1,-1], [ 1,-1,-1], [ 1, 1,-1], [-1, 1,-1],
    [-1,-1, 1], [ 1,-1, 1], [ 1, 1, 1], [-1, 1, 1]
])
faces = [[0,1,2,3], [4,5,6,7], [0,1,5,4],
         [2,3,7,6], [0,3,7,4], [1,2,6,5]]

fig = plt.figure()
ax = fig.add_subplot(111, projection="3d")
ax.set_xlim(-2, 2)
ax.set_ylim(-2, 2)
ax.set_zlim(-2, 2)
ax.set_box_aspect([1, 1, 1])
ax.set_xlabel("X")
ax.set_ylabel("Y")
ax.set_zlabel("Z")

cube = Poly3DCollection(
    [[v[i] for i in f] for f in faces],
    facecolors=["tab:red", "tab:blue", "tab:green", "tab:orange", "tab:purple", "tab:cyan"],
    # alpha=0.7
)
ax.add_collection3d(cube)

def reset_orientation(event):
    global q
    if event.key in ("r", "R"):
        q = np.array([1., 0., 0., 0.])

fig.canvas.mpl_connect("key_press_event", reset_orientation)

next_draw = time.perf_counter()

try:
    while plt.fignum_exists(fig.number):

        # Process ALL samples currently waiting in the serial buffer.
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

            # One Madgwick update for EVERY IMU sample.
            q = madgwick.updateIMU(
                q,
                gyr=np.radians([gx, gy, gz]),
                acc=np.array([ax, ay, az])
            )

        # Render at ~60 FPS independently of sensor rate.
        now = time.perf_counter()

        if now >= next_draw:
            r = Rotation.from_quat([q[1], q[2], q[3], q[0]])
            p = r.apply(v)

            cube.set_verts([[p[i] for i in f] for f in faces])

            fig.canvas.draw_idle()
            fig.canvas.flush_events()

            next_draw = now + 1 / DISPLAY_HZ

        plt.pause(0.001)

except KeyboardInterrupt:
    pass

ser.close()
