// All BLE UUIDs and the protocol description of this firmware. Must match
// lib/data/ble/ble_protocol.dart in the app. All multi-byte values are little-endian.
#pragma once

// ============================================================================
// OpenToF custom protocol, version 1 (PROTOCOL_VERSION)
// ============================================================================
// see ../docs/PROTOCOL.md for details

#define PROTOCOL_VERSION 1

#define UUID_JUMP_SERVICE "6f70656e-546f-4600-0001-000000000000"
#define UUID_NAME "6f70656e-546f-4600-0004-000000000000"
#define UUID_EVENT "6f70656e-546f-4600-0005-000000000000"
#define UUID_FIELDS "6f70656e-546f-4600-0007-000000000000"
#define UUID_REASONS "6f70656e-546f-4600-0008-000000000000"
#define UUID_CONFIDENCE_KIND "6f70656e-546f-4600-0009-000000000000"

// Human-readable descriptions of the custom characteristics. They are sent as GATT
// "Characteristic User Description" descriptors (0x2901).
// A service cannot carry a description, the standard characteristics are well-known.
#define SIG_DESC_USER_DESCRIPTION "2901"
#define DESC_EVENT "Detected devents"
#define DESC_FIELDS "Custom event fields metadata"
#define DESC_REASONS "Reason bit metadata"
#define DESC_CONFIDENCE_KIND "Confidence kind"
#define DESC_NAME "Device name"

// ============================================================================
// Bluetooth SIG assigned 16-bit UUIDs (Assigned Numbers)
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
