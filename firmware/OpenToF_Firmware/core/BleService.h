// The BLE GATT server: jump service, battery service, device information service.
// UUIDs and payload layouts are described in config/BleUuids.h.
#pragma once

#include <ArduinoBLE.h>

#include "../config/BleUuids.h"
#include "../config/FirmwareConfig.h"
#include "DeviceName.h"
#include "Logging.h"

// Longest string a Device Information characteristic can hold.
static const int DIS_STRING_MAX = 32;
#define DIS_CHECK(s) static_assert(sizeof(s) - 1 <= DIS_STRING_MAX, #s " is too long for BLE")
DIS_CHECK(FIRMWARE_VERSION);
DIS_CHECK(HARDWARE_REVISION);
DIS_CHECK(MANUFACTURER_NAME);
DIS_CHECK(MODEL_NUMBER);

// ---- Jump service ----
static BLEService jumpService(UUID_JUMP_SERVICE);
static BLECharacteristic landingChar(UUID_LANDING, BLENotify, 8, true);
static BLECharacteristic takeoffChar(UUID_TAKEOFF, BLENotify, 8, true);
static BLECharacteristic nameChar(UUID_NAME, BLERead | BLEWrite, NAME_MAX_BYTES, false);
static BLEDescriptor landingDescription(SIG_DESC_USER_DESCRIPTION, DESC_LANDING);
static BLEDescriptor takeoffDescription(SIG_DESC_USER_DESCRIPTION, DESC_TAKEOFF);
static BLEDescriptor nameDescription(SIG_DESC_USER_DESCRIPTION, DESC_NAME);

// ---- Battery service ----
static BLEService batteryService(SIG_SVC_BATTERY);
static BLEUnsignedCharCharacteristic batteryLevelChar(SIG_CHR_BATTERY_LEVEL, BLERead | BLENotify);

// ---- Device information service ----
static BLEService deviceInfoService(SIG_SVC_DEVICE_INFORMATION);
static BLEStringCharacteristic manufacturerNameChar(SIG_CHR_MANUFACTURER_NAME, BLERead,
                                                    DIS_STRING_MAX);
static BLEStringCharacteristic modelNumberChar(SIG_CHR_MODEL_NUMBER, BLERead, DIS_STRING_MAX);
static BLEStringCharacteristic serialNumberChar(SIG_CHR_SERIAL_NUMBER, BLERead, DIS_STRING_MAX);
static BLEStringCharacteristic hardwareRevisionChar(SIG_CHR_HARDWARE_REVISION, BLERead,
                                                    DIS_STRING_MAX);
static BLEStringCharacteristic firmwareRevisionChar(SIG_CHR_FIRMWARE_REVISION, BLERead,
                                                    DIS_STRING_MAX);
static BLEStringCharacteristic softwareRevisionChar(SIG_CHR_SOFTWARE_REVISION, BLERead,
                                                    DIS_STRING_MAX);

static uint32_t landingSeq = 0;
static uint32_t takeoffSeq = 0;

static void putU32LE(uint8_t* p, uint32_t v) {
  p[0] = (uint8_t)v;
  p[1] = (uint8_t)(v >> 8);
  p[2] = (uint8_t)(v >> 16);
  p[3] = (uint8_t)(v >> 24);
}

// Sends {duration_ms, sequence} as a notification (dropped by the stack if nobody is subscribed).
static void notifyEvent(const char* label, BLECharacteristic& c, uint32_t durationMs,
                        uint32_t seq) {
  uint8_t payload[8];
  putU32LE(payload, durationMs);
  putU32LE(payload + 4, seq);
  c.writeValue(payload, sizeof(payload));
  if (!c.subscribed()) {
    // The algorithm IS detecting jumps; they just aren't reaching a phone. Usually: no app
    // connected yet, or connected but hasn't enabled notifications on this characteristic.
    LOG(String(label) + ": no app subscribed, notification dropped");
  }
}

static void bleNotifyLanding(uint32_t flightMs) {
  notifyEvent("landing", landingChar, flightMs, landingSeq++);
}
static void bleNotifyTakeoff(uint32_t contactMs) {
  notifyEvent("takeoff", takeoffChar, contactMs, takeoffSeq++);
}

static void bleSetBatteryLevel(uint8_t percent) { batteryLevelChar.writeValue(percent); }

static void onNameWritten(BLEDevice central, BLECharacteristic characteristic) {
  (void)central;
  uint8_t buf[NAME_MAX_BYTES + 1];
  const int len = characteristic.valueLength();
  bool ok = len >= 1 && len <= NAME_MAX_BYTES;
  if (ok) {
    characteristic.readValue(buf, len);
    ok = trySetDeviceName(buf, (size_t)len);
  }
  if (ok) {
    BLE.setLocalName(deviceName);
    BLE.setDeviceName(deviceName);
    LOG(String("Name set to: ") + deviceName);  // flash write happens in loop()
  } else {
    // ArduinoBLE cannot reject a write, so restore the previous value.
    nameChar.writeValue((const uint8_t*)deviceName, strlen(deviceName));
    LOG("Rejected invalid device name");
  }
}

static void onConnected(BLEDevice central) {
  (void)central;
  digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
  LOG("BLE connected");
}

static void onDisconnected(BLEDevice central) {
  (void)central;
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  LOG("BLE disconnected");
}

// Starts the BLE stack and registers all services. Call after loadDeviceName().
// `algorithmName` (the active jump detector) is published as the Software Revision String,
// cut to DIS_STRING_MAX bytes. Returns false if the stack fails to start.
// Advertising starts with bleStartAdvertising().
static bool bleBegin(const char* algorithmName) {
  if (!BLE.begin()) return false;
  BLE.setLocalName(deviceName);
  BLE.setDeviceName(deviceName);
  BLE.setAppearance(BLE_APPEARANCE);
  BLE.setAdvertisedService(jumpService);  // only the jump service is advertised (app scan filter)
  BLE.setAdvertisingInterval(BLE_ADV_INTERVAL);
  BLE.setConnectionInterval(BLE_CONN_INTERVAL_MIN, BLE_CONN_INTERVAL_MAX);

  // Descriptors must be attached before the service is added.
  landingChar.addDescriptor(landingDescription);
  takeoffChar.addDescriptor(takeoffDescription);
  nameChar.addDescriptor(nameDescription);

  jumpService.addCharacteristic(landingChar);
  jumpService.addCharacteristic(takeoffChar);
  jumpService.addCharacteristic(nameChar);
  batteryService.addCharacteristic(batteryLevelChar);
  deviceInfoService.addCharacteristic(manufacturerNameChar);
  deviceInfoService.addCharacteristic(modelNumberChar);
  deviceInfoService.addCharacteristic(serialNumberChar);
  deviceInfoService.addCharacteristic(hardwareRevisionChar);
  deviceInfoService.addCharacteristic(firmwareRevisionChar);
  deviceInfoService.addCharacteristic(softwareRevisionChar);
  BLE.addService(jumpService);
  BLE.addService(batteryService);
  BLE.addService(deviceInfoService);

  nameChar.writeValue((const uint8_t*)deviceName, strlen(deviceName));
  nameChar.setEventHandler(BLEWritten, onNameWritten);

  manufacturerNameChar.writeValue(MANUFACTURER_NAME);
  modelNumberChar.writeValue(MODEL_NUMBER);
  serialNumberChar.writeValue(BLE.address());  // BLE device address: unique per chip
  hardwareRevisionChar.writeValue(HARDWARE_REVISION);
  firmwareRevisionChar.writeValue(FIRMWARE_VERSION);
  softwareRevisionChar.writeValue(String(algorithmName).substring(0, DIS_STRING_MAX));

  BLE.setEventHandler(BLEConnected, onConnected);
  BLE.setEventHandler(BLEDisconnected, onDisconnected);
  return true;
}

static void bleStartAdvertising() {
  BLE.advertise();
  LOG(String("Advertising as ") + deviceName);
}

// Call every loop(): services the stack and resumes advertising after a disconnect so the
// app can reconnect.
static void blePoll() {
  static bool wasConnected = false;
  BLE.poll();
  const bool connected = BLE.connected();
  if (wasConnected && !connected) BLE.advertise();
  wasConnected = connected;
}
