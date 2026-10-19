// Device name: persisted in flash (EEPROM library)
#pragma once

#include <Arduino.h>
#include <EEPROM.h>
#include <string.h>

#include "../config/FirmwareConfig.h"

// EEPROM layout: [0]=0x4F [1]=0x54 (magic) [2]=length [3..]=UTF-8 bytes
static const int EE_MAGIC0 = 0x4F;
static const int EE_MAGIC1 = 0x54;
static char deviceName[NAME_MAX_BYTES + 1] = DEFAULT_DEVICE_NAME; //+1 for zero-terminator
static bool nameDirty = false;  // needs to be written to flash (done by flushDeviceName())

static void loadDeviceName() {
  if (EEPROM.read(0) != EE_MAGIC0 || EEPROM.read(1) != EE_MAGIC1) return;
  const uint8_t len = EEPROM.read(2);
  if (len < 1 || len > NAME_MAX_BYTES) return;
  uint8_t buf[NAME_MAX_BYTES];
  for (uint8_t i = 0; i < len; i++) buf[i] = EEPROM.read(3 + i);
  memcpy(deviceName, buf, len);
  deviceName[len] = '\0';
}

// Set and save a new device name. `n` is the length in bytes.
static bool setDeviceName(const uint8_t* s, size_t n) {
  if (n < 1 || n > NAME_MAX_BYTES) return false;
  memcpy(deviceName, s, n);
  deviceName[n] = '\0';
  EEPROM.write(0, EE_MAGIC0);
  EEPROM.write(1, EE_MAGIC1);
  EEPROM.write(2, n);
  for (uint8_t i = 0; i < n; i++) EEPROM.write(3 + i, (uint8_t)deviceName[i]);
  return true;
}
