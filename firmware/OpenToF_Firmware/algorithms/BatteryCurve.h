// Battery algorithm: cell voltage -> percent. Replace the table with a measured curve
// (or the whole function) for better accuracy.
#pragma once

#include <stdint.h>

struct BatteryPoint {
  float volts;
  uint8_t percent;
};

// Rough single-cell LiPo discharge curve, highest voltage first.
static const BatteryPoint BATTERY_CURVE[] = {
    {4.20f, 100}, {4.10f, 90}, {4.00f, 80}, {3.92f, 70}, {3.87f, 60}, {3.82f, 50},
    {3.79f, 40},  {3.77f, 30}, {3.73f, 20}, {3.70f, 10}, {3.50f, 5},  {3.30f, 0},
};

// Linear interpolation between the table points; clamped to 0..100.
static uint8_t batteryPercent(float v) {
  const int n = sizeof(BATTERY_CURVE) / sizeof(BATTERY_CURVE[0]);
  if (v >= BATTERY_CURVE[0].volts) return 100;
  for (int i = 1; i < n; i++) {
    if (v >= BATTERY_CURVE[i].volts) {
      const BatteryPoint& hi = BATTERY_CURVE[i - 1];
      const BatteryPoint& lo = BATTERY_CURVE[i];
      const float f = (v - lo.volts) / (hi.volts - lo.volts);
      return (uint8_t)(lo.percent + f * (hi.percent - lo.percent) + 0.5f);
    }
  }
  return 0;
}
