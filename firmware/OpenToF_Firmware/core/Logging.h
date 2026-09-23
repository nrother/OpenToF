// LOG(...): debug text over Serial. Compiles to nothing when DEBUG_SERIAL is 0.
#pragma once

#include <Arduino.h>

#include "../config/FirmwareConfig.h"

#if DEBUG_SERIAL
static void logLine(const String& text) {
#if IMU_SERIAL_LOG
  Serial.print("# ");  // keep the CSV stream parseable
#endif
  Serial.println(text);
}
#define LOG(...) logLine(String(__VA_ARGS__))
#else
#define LOG(...)
#endif
