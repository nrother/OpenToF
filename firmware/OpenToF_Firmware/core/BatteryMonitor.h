// Battery hardware: single-cell LiPo on the XIAO's charger, read through a 1/2 divider.
#pragma once

#include <stdint.h>
#include <Arduino.h>

#include "../config/FirmwareConfig.h"
#include "Logging.h"

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
static uint8_t batteryVoltToPercent(float v) {
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

static float readBatteryVolts() {
  pinMode(BATTERY_ENABLE_ADC_PIN, OUTPUT);
  digitalWrite(BATTERY_ENABLE_ADC_PIN, HIGH);
  delay(2);  // let the divider settle
  analogReadResolution(12);
  uint32_t sum = 0;
  // read 8 times and average
  for (int i = 0; i < 8; i++) sum += analogRead(BATTERY_SENSE_PIN);
  digitalWrite(BATTERY_ENABLE_ADC_PIN, LOW);  // divider off: no idle drain
  return (sum / 8.0f) * (2.0f * 3.3f / 4095.0f);
}

class BatteryMonitor {
 public:
  // Measures when due (every BATTERY_INTERVAL_MS) or when `force` is set.
  // Returns true if the percentage changed
  bool update(bool force) {
    const uint32_t now = millis();
    if (!force && now - _lastMs < BATTERY_INTERVAL_MS) return false;
    _lastMs = now;
    _volts = readBatteryVolts();
    const uint8_t pct = batteryVoltToPercent(_volts);
    if (pct == _percent) return false;
    _percent = pct;
    LOG(String("battery ") + _volts + " V -> " + pct + " %");
    return true;
  }

  uint8_t percent() const { return _percent; }
  float volts() const { return _volts; }

 private:
  uint32_t _lastMs = 0;
  uint8_t _percent = 255;  // 255 = not measured yet
  float _volts = 0.0f;
};
