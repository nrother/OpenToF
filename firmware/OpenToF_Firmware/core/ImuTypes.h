// IMU data types shared by the IMU driver and the jump-detection algorithms.
#pragma once

#include <math.h>
#include <stdint.h>

// One IMU sample as handed to the algorithm. Values are already converted to SI units.
//
// Axes are the BOARD's axes, +Z is down for the desired mounting
struct ImuData {
  uint64_t timeUs;  // when the sample was read: microseconds since boot
  float dt;         // seconds since the previous sample (about 1/samples-per-second)

  float ax, ay, az;  // acceleration in g (1.0 g = gravity; a sensor at rest reads ~1.0 g total)
  float gx, gy, gz;  // rotation rate in degrees per second

  float accelMagnitude() const { return sqrtf(ax * ax + ay * ay + az * az); }
  float gyroMagnitude() const { return sqrtf(gx * gx + gy * gy + gz * gz); }
};
