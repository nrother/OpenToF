// Battery hardware: single-cell LiPo on the XIAO's charger, read through a 1/2 divider.
// Converting volts to percent is in BatteryCurve.h.
#pragma once

#include <Arduino.h>

#include "../algorithms/BatteryCurve.h"
#include "../config/FirmwareConfig.h"
#include "Logging.h"

static float readBatteryVolts() {
  pinMode(BATTERY_ENABLE_PIN, OUTPUT);
  digitalWrite(BATTERY_ENABLE_PIN, HIGH);
  delay(2);  // let the divider settle
  analogReadResolution(12);
  uint32_t sum = 0;
  for (int i = 0; i < 8; i++) sum += analogRead(BATTERY_SENSE_PIN);
  digitalWrite(BATTERY_ENABLE_PIN, LOW);  // divider off: no idle drain
  return (sum / 8.0f) * (2.0f * 3.3f / 4095.0f);
}

class BatteryMonitor {
 public:
  // Measures when due (every BATTERY_INTERVAL_MS) or when `force` is set.
  // Returns true if the percentage changed, so the caller can publish the new level.
  bool update(bool force) {
    const uint32_t now = millis();
    if (!force && now - _lastMs < BATTERY_INTERVAL_MS) return false;
    _lastMs = now;
    _volts = readBatteryVolts();
    const uint8_t pct = batteryPercent(_volts);
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
