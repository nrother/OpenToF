// Device health wire format, independent of the jump event protocol version.
#pragma once

#include <stdint.h>
#include <string.h>

static_assert(__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__, "HealthStatus encoding requires a little-endian device");

struct HealthStatus {
  bool pllAvailable = false;
  bool pllLocked = false;
  float pllFrequencyHz = 0.0f;
  uint32_t uptimeSeconds = 0;
};

static const uint8_t HEALTH_VERSION = 1;
static const int HEALTH_BYTES = 10;

static void encodeHealth(const HealthStatus& health, uint8_t* payload) {
  payload[0] = HEALTH_VERSION;
  payload[1] = health.pllAvailable ? (1 | (health.pllLocked ? 2 : 0)) : 0;
  const uint32_t frequencyMilliHz = health.pllAvailable
      ? static_cast<uint32_t>(health.pllFrequencyHz * 1000.0f + 0.5f) : 0;
  memcpy(payload + 2, &frequencyMilliHz, sizeof(frequencyMilliHz));
  memcpy(payload + 6, &health.uptimeSeconds, sizeof(health.uptimeSeconds));
}
