// 64-bit microseconds since boot (micros() wraps every ~71 minutes).
// Call it at least once per wrap period (the main loop does, many times per second).
#pragma once

#include <Arduino.h>
#include <stdint.h>

static uint64_t micros64() {
  static uint32_t lastLow = 0;
  static uint32_t wraps = 0;
  const uint32_t now = micros();
  if (now < lastLow) wraps++;
  lastLow = now;
  return ((uint64_t)wraps << 32) | now;
}
