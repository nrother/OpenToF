// Boot counter: persisted in flash (EEPROM library), incremented on every start. The app reads
// it (Info characteristic) to notice that the device clock restarted.
#pragma once

#include <EEPROM.h>
#include <stdint.h>

// EEPROM layout: [32]=0x42 [33]=0x43 (magic) [34..35]=count, little-endian.
// Bytes 0..22 belong to the device name (DeviceName.h).
static const int EE_BOOT_ADDR = 32;
static uint16_t bootCount = 0;

// Reads, increments and stores the counter. Call once in setup().
static void incrementBootCount() {
  uint16_t count = 0;
  if (EEPROM.read(EE_BOOT_ADDR) == 0x42 && EEPROM.read(EE_BOOT_ADDR + 1) == 0x43) {
    count = (uint16_t)(EEPROM.read(EE_BOOT_ADDR + 2) | (EEPROM.read(EE_BOOT_ADDR + 3) << 8));
  }
  bootCount = (uint16_t)(count + 1);
  EEPROM.update(EE_BOOT_ADDR, 0x42);
  EEPROM.update(EE_BOOT_ADDR + 1, 0x43);
  EEPROM.write(EE_BOOT_ADDR + 2, (uint8_t)bootCount);
  EEPROM.write(EE_BOOT_ADDR + 3, (uint8_t)(bootCount >> 8));
}
