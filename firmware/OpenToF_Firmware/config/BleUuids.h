// All BLE UUIDs and the protocol description of this firmware. Must match
// lib/data/ble/ble_protocol.dart in the app. All multi-byte values are little-endian.
#pragma once

// ============================================================================
// OpenToF custom protocol
// !! These four 128-bit UUIDs are PLACEHOLDERS until agreed with the app team.
// ============================================================================
//   Jump service   (advertised; the app scans for it)
//     Landing  Notify      flight_time_ms  uint32, sequence_number uint32
//     Takeoff  Notify      contact_time_ms uint32, sequence_number uint32
//     Name     Read/Write  UTF-8, 1..NAME_MAX_BYTES bytes, stored in flash
//
// Event semantics
//   Contact time is the one BEFORE a jump (previous landing -> this takeoff), so a takeoff
//   event (carrying that contact time) is sent when the takeoff happens, before the landing
//   event of the same jump. Each characteristic has its own sequence counter that increments
//   for every event, even when no phone is connected, so the app can detect missed events.
//   The very first takeoff after boot has no preceding landing: no takeoff event is sent
//   (no counter consumed) and the app shows that contact time as unknown.

#define UUID_JUMP_SERVICE "6f70656e-546f-4600-0001-000000000000"
#define UUID_LANDING "6f70656e-546f-4600-0002-000000000000"
#define UUID_TAKEOFF "6f70656e-546f-4600-0003-000000000000"
#define UUID_NAME "6f70656e-546f-4600-0004-000000000000"

// Human-readable descriptions of the custom characteristics. They are sent as GATT
// "Characteristic User Description" descriptors (0x2901), which scanner apps such as
// nRF Connect show under the characteristic. Keep them short (they are read over BLE).
// A service cannot carry a description; the standard characteristics need none because
// scanners know their names.
#define SIG_DESC_USER_DESCRIPTION "2901"
#define DESC_LANDING "Landing: flight time [ms] u32, seq u32"
#define DESC_TAKEOFF "Takeoff: contact time [ms] u32, seq u32"
#define DESC_NAME "Device name (UTF-8, writable)"

// ============================================================================
// Bluetooth SIG assigned 16-bit UUIDs (Assigned Numbers, bluetooth.com)
// Cross-checked against the Nordic bluetooth-numbers-database, Zephyr and bleak.
// ============================================================================

// ---- Used by this firmware -------------------------------------------------

// Battery Service 0x180F
#define SIG_SVC_BATTERY "180F"
#define SIG_CHR_BATTERY_LEVEL "2A19"  // Read/Notify, uint8 0..100 %

// Device Information Service 0x180A (all Read, UTF-8 strings)
#define SIG_SVC_DEVICE_INFORMATION "180A"
#define SIG_CHR_MANUFACTURER_NAME "2A29"
#define SIG_CHR_MODEL_NUMBER "2A24"
#define SIG_CHR_SERIAL_NUMBER "2A25"
#define SIG_CHR_HARDWARE_REVISION "2A27"
#define SIG_CHR_FIRMWARE_REVISION "2A26"
#define SIG_CHR_SOFTWARE_REVISION "2A28"  // name of the active jump-detection algorithm

// ---- Not used yet: plausible additions -------------------------------------
// Generic Access 0x1800 / Generic Attribute 0x1801 are provided by the BLE stack:
//   Device Name 0x2A00, Appearance 0x2A01 (set via BLE_APPEARANCE), Service Changed 0x2A05.

// Device Information Service extras
#define SIG_CHR_SYSTEM_ID "2A23"  // 40-bit manufacturer id + 24-bit OUI
#define SIG_CHR_PNP_ID "2A50"     // vendor id source/vendor id/product id/version

// Battery Service extras (all optional in the service)
#define SIG_CHR_BATTERY_POWER_STATE "2A1A"      // present/discharging/charging/level flags
#define SIG_CHR_BATTERY_CRITICAL_STATUS "2BE9"  // critical power / immediate service flags
#define SIG_CHR_BATTERY_HEALTH_STATUS "2BEA"
#define SIG_CHR_BATTERY_HEALTH_INFORMATION "2BEB"
#define SIG_CHR_BATTERY_INFORMATION "2BEC"   // chemistry, nominal capacity, cycles, ...
#define SIG_CHR_BATTERY_LEVEL_STATUS "2BED"  // power state flags (needs a charger signal we lack)
#define SIG_CHR_BATTERY_TIME_STATUS "2BEE"  // time until discharged / recharged (minutes)
#define SIG_CHR_ESTIMATED_SERVICE_DATE "2BEF"
#define SIG_CHR_BATTERY_ENERGY_STATUS "2BF0"

// Other services that might fit later
#define SIG_SVC_ENVIRONMENTAL_SENSING "181A"  // with Temperature 0x2A6E (sint16, 0.01 degC)
#define SIG_CHR_TEMPERATURE "2A6E"
#define SIG_SVC_DEVICE_TIME "1847"  // Device Time 0x2B90, Current Elapsed Time 0x2BF2
#define SIG_CHR_DEVICE_TIME "2B90"
