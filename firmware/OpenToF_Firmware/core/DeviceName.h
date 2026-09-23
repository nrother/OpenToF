// Device name: persisted in flash (EEPROM library) and validated (UTF-8, no control chars).
#pragma once

#include <Arduino.h>
#include <EEPROM.h>
#include <string.h>

#include "../config/FirmwareConfig.h"

// EEPROM layout: [0]=0x4F [1]=0x54 (magic) [2]=length [3..]=UTF-8 bytes
static const int EE_MAGIC0 = 0x4F;
static const int EE_MAGIC1 = 0x54;
static char deviceName[NAME_MAX_BYTES + 1] = DEFAULT_DEVICE_NAME;
static bool nameDirty = false;  // needs to be written to flash (done by flushDeviceName())

static bool isValidUtf8Name(const uint8_t* s, size_t n) {
  if (n < 1 || n > NAME_MAX_BYTES) return false;
  size_t i = 0;
  while (i < n) {
    const uint8_t c = s[i];
    if (c < 0x20 || c == 0x7F) return false;  // no control characters
    if (c < 0x80) {
      i++;
      continue;
    }
    size_t extra;
    uint32_t minCp;
    if ((c & 0xE0) == 0xC0) {
      extra = 1;
      minCp = 0x80;
    } else if ((c & 0xF0) == 0xE0) {
      extra = 2;
      minCp = 0x800;
    } else if ((c & 0xF8) == 0xF0) {
      extra = 3;
      minCp = 0x10000;
    } else {
      return false;
    }
    if (i + extra >= n) return false;
    uint32_t cp = c & (0x3F >> extra);
    for (size_t k = 1; k <= extra; k++) {
      if ((s[i + k] & 0xC0) != 0x80) return false;
      cp = (cp << 6) | (s[i + k] & 0x3F);
    }
    if (cp < minCp || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) return false;
    i += extra + 1;
  }
  return true;
}

static void loadDeviceName() {
  if (EEPROM.read(0) != EE_MAGIC0 || EEPROM.read(1) != EE_MAGIC1) return;
  const uint8_t len = EEPROM.read(2);
  if (len < 1 || len > NAME_MAX_BYTES) return;
  uint8_t buf[NAME_MAX_BYTES];
  for (uint8_t i = 0; i < len; i++) buf[i] = EEPROM.read(3 + i);
  if (!isValidUtf8Name(buf, len)) return;
  memcpy(deviceName, buf, len);
  deviceName[len] = '\0';
}

static void saveDeviceName() {
  const uint8_t len = (uint8_t)strlen(deviceName);
  EEPROM.write(0, EE_MAGIC0);
  EEPROM.write(1, EE_MAGIC1);
  EEPROM.write(2, len);
  for (uint8_t i = 0; i < len; i++) EEPROM.write(3 + i, (uint8_t)deviceName[i]);
}

// Takes a new name if valid (and marks it for saving); returns false and changes nothing if not.
static bool trySetDeviceName(const uint8_t* s, size_t n) {
  if (!isValidUtf8Name(s, n)) return false;
  memcpy(deviceName, s, n);
  deviceName[n] = '\0';
  nameDirty = true;
  return true;
}

// Writes a changed name to flash. Call from loop(), not from a BLE callback.
static void flushDeviceName() {
  if (!nameDirty) return;
  saveDeviceName();
  nameDirty = false;
}
