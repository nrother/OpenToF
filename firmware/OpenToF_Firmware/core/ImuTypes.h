// IMU data types shared by the IMU driver and the jump-detection algorithms.
#pragma once

#include <math.h>
#include <stdint.h>

// IMU settings. Two are available; a detector can pick one via imuProfile().
struct ImuProfile {
  const char* name;
  uint16_t odrHz;             // accel + gyro output data rate = samples per second
  uint8_t accelRangeG;        // measurement range +-g
  uint16_t accelBandwidthHz;  // anti-alias filter
  float accelLsbPerG;
  uint16_t gyroRangeDps;      // measurement range +-deg/s
  float gyroMdpsPerLsb;
};

static const ImuProfile PROFILE_416HZ_8G = {"416Hz/8g", 416, 8, 200, 4096.0f, 500, 17.5f};
static const ImuProfile PROFILE_833HZ_16G = {"833Hz/16g", 833, 16, 400, 2048.0f, 500, 17.5f};

// One IMU sample as handed to your algorithm. Values are already converted to real units.
//
// Axes are the BOARD's axes; which way they point in the world depends on how the sensor is
// mounted on the trampoline frame. If the mounting is not fixed, prefer orientation-independent
// values such as accelMagnitude() and gyroMagnitude().
struct ImuData {
  uint64_t timeUs;  // when the sample was read: microseconds since boot
  float dt;         // seconds since the previous sample (about 1/samples-per-second)

  float ax, ay, az;  // acceleration in g (1.0 g = gravity; a sensor at rest reads ~1.0 g total)
  float gx, gy, gz;  // rotation rate in degrees per second

  float accelMagnitude() const { return sqrtf(ax * ax + ay * ay + az * az); }
  float gyroMagnitude() const { return sqrtf(gx * gx + gy * gy + gz * gz); }
};
