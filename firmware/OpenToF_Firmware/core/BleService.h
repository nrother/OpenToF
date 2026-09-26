// The BLE GATT server: jump service, battery service, device information service.
// UUIDs and payload layouts are described in config/BleUuids.h.
#pragma once

#include <ArduinoBLE.h>

#include "../config/BleUuids.h"
#include "../config/FirmwareConfig.h"
#include "BootCounter.h"
#include "DeviceName.h"
#include "Logging.h"
#include "Micros64.h"
#include "Transition.h"

// Longest string a Device Information characteristic can hold.
static const int DIS_STRING_MAX = 32;
#define DIS_CHECK(s) static_assert(sizeof(s) - 1 <= DIS_STRING_MAX, #s " is too long for BLE")
DIS_CHECK(FIRMWARE_VERSION);
DIS_CHECK(HARDWARE_REVISION);
DIS_CHECK(MANUFACTURER_NAME);
DIS_CHECK(MODEL_NUMBER);

// ---- Jump service ----
static BLEService jumpService(UUID_JUMP_SERVICE);
static const int EVENT_FIXED_BYTES = 10;
static const int INFO_BYTES = 7;
static const int META_MAX_BYTES = 512;  // longest value a BLE attribute can hold
static BLECharacteristic eventChar(UUID_EVENT, BLENotify, EVENT_FIXED_BYTES + EVENT_EXTRAS_MAX,
                                   false);
static BLECharacteristic infoChar(UUID_INFO, BLERead, INFO_BYTES, true);
static BLECharacteristic fieldsChar(UUID_FIELDS, BLERead, META_MAX_BYTES, false);
static BLECharacteristic reasonsChar(UUID_REASONS, BLERead, META_MAX_BYTES, false);
static BLECharacteristic confidenceKindChar(UUID_CONFIDENCE_KIND, BLERead, META_MAX_BYTES, false);
static BLECharacteristic nameChar(UUID_NAME, BLERead | BLEWrite, NAME_MAX_BYTES, false);
static BLEDescriptor eventDescription(SIG_DESC_USER_DESCRIPTION, DESC_EVENT);
static BLEDescriptor infoDescription(SIG_DESC_USER_DESCRIPTION, DESC_INFO);
static BLEDescriptor fieldsDescription(SIG_DESC_USER_DESCRIPTION, DESC_FIELDS);
static BLEDescriptor reasonsDescription(SIG_DESC_USER_DESCRIPTION, DESC_REASONS);
static BLEDescriptor confidenceKindDescription(SIG_DESC_USER_DESCRIPTION, DESC_CONFIDENCE_KIND);
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

static void putU32LE(uint8_t* p, uint32_t v) {
  p[0] = (uint8_t)v;
  p[1] = (uint8_t)(v >> 8);
  p[2] = (uint8_t)(v >> 16);
  p[3] = (uint8_t)(v >> 24);
}

// Event `kind` byte: bit 0 = landing, bits 1..2 = stage.
static const uint8_t EVENT_STAGE_PROVISIONAL = 0;
static const uint8_t EVENT_STAGE_FINAL = 1;
static const uint8_t EVENT_STAGE_RETRACTED = 2;

// Sends one event notification (layout in BleUuids.h). Dropped by the stack if nobody is
// subscribed; nothing is buffered.
static void bleNotifyEvent(uint16_t jumpId, bool landing, uint8_t stage, uint32_t timeMs,
                           const EventInfo& info) {
  uint8_t payload[EVENT_FIXED_BYTES + EVENT_EXTRAS_MAX];
  payload[0] = PROTOCOL_VERSION;
  payload[1] = (uint8_t)jumpId;
  payload[2] = (uint8_t)(jumpId >> 8);
  payload[3] = (uint8_t)((landing ? 1 : 0) | (stage << 1));
  putU32LE(payload + 4, timeMs);
  payload[8] = info.confidence;
  payload[9] = info.reasons;
  const uint8_t n = info.extrasLen <= EVENT_EXTRAS_MAX ? info.extrasLen : EVENT_EXTRAS_MAX;
  memcpy(payload + EVENT_FIXED_BYTES, info.extras, n);
  eventChar.writeValue(payload, EVENT_FIXED_BYTES + n);
  if (!eventChar.subscribed()) {
    // The algorithm IS detecting jumps; they just aren't reaching a phone. Usually: no app
    // connected yet, or connected but hasn't enabled notifications on this characteristic.
    LOG("event: no app subscribed, notification dropped");
  }
}

// Info = {proto, boot count, current device time}; refreshed right before every read.
static void updateInfo() {
  uint8_t v[INFO_BYTES];
  v[0] = PROTOCOL_VERSION;
  v[1] = (uint8_t)bootCount;
  v[2] = (uint8_t)(bootCount >> 8);
  putU32LE(v + 3, (uint32_t)(micros64() / 1000ULL));
  infoChar.writeValue(v, sizeof(v));
}

static void onInfoRead(BLEDevice central, BLECharacteristic characteristic) {
  (void)central;
  (void)characteristic;
  updateInfo();
}

// Publishes an algorithm description string, cut to META_MAX_BYTES.
static void setMetaString(BLECharacteristic& c, const char* label, const char* text) {
  size_t len = strlen(text);
  if (len > (size_t)META_MAX_BYTES) {
    LOG(String(label) + " is longer than 512 bytes, truncated");
    len = META_MAX_BYTES;
  }
  // With the default MTU a long read fetches 22-byte pieces. ArduinoBLE answers a read at
  // offset == length with an error instead of an empty value, which can fail the whole long
  // read when the length is an exact multiple of 22, so pad with a (JSON-neutral) space.
  static uint8_t buf[META_MAX_BYTES];
  memcpy(buf, text, len);
  if (len > 0 && len % 22 == 0 && len < (size_t)META_MAX_BYTES) buf[len++] = ' ';
  c.writeValue(buf, len);
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
// `algorithm` (the active jump detector or the demo) is described over BLE: its name as the
// Software Revision String (cut to DIS_STRING_MAX bytes), its field/reason/confidence strings in
// the Fields, Reasons and Confidence kind characteristics. Returns false if the stack fails to start.
// Advertising starts with bleStartAdvertising().
static bool bleBegin(const TransitionSource& algorithm) {
  if (!BLE.begin()) return false;
  BLE.setLocalName(deviceName);
  BLE.setDeviceName(deviceName);
  BLE.setAppearance(BLE_APPEARANCE);
  BLE.setAdvertisedService(jumpService);  // only the jump service is advertised (app scan filter)
  BLE.setAdvertisingInterval(BLE_ADV_INTERVAL);
  BLE.setConnectionInterval(BLE_CONN_INTERVAL_MIN, BLE_CONN_INTERVAL_MAX);

  // Descriptors must be attached before the service is added.
  eventChar.addDescriptor(eventDescription);
  infoChar.addDescriptor(infoDescription);
  fieldsChar.addDescriptor(fieldsDescription);
  reasonsChar.addDescriptor(reasonsDescription);
  confidenceKindChar.addDescriptor(confidenceKindDescription);
  nameChar.addDescriptor(nameDescription);

  jumpService.addCharacteristic(eventChar);
  jumpService.addCharacteristic(infoChar);
  jumpService.addCharacteristic(fieldsChar);
  jumpService.addCharacteristic(reasonsChar);
  jumpService.addCharacteristic(confidenceKindChar);
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
  updateInfo();
  infoChar.setEventHandler(BLERead, onInfoRead);
  setMetaString(fieldsChar, "fieldsJson()", algorithm.fieldsJson());
  setMetaString(reasonsChar, "reasonsJson()", algorithm.reasonsJson());
  setMetaString(confidenceKindChar, "confidenceKind()", algorithm.confidenceKind());

  manufacturerNameChar.writeValue(MANUFACTURER_NAME);
  modelNumberChar.writeValue(MODEL_NUMBER);
  serialNumberChar.writeValue(BLE.address());  // BLE device address: unique per chip
  hardwareRevisionChar.writeValue(HARDWARE_REVISION);
  firmwareRevisionChar.writeValue(FIRMWARE_VERSION);
  softwareRevisionChar.writeValue(String(algorithm.name()).substring(0, DIS_STRING_MAX));

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
