// All settings of the firmware in one place. Edit here, not in the other files.
#pragma once

// ============================================================================
// Modes
// ============================================================================

// 0 = use the real IMU + the active jump detector (picked at the top of the .ino).
// 1 = simulate jumps instead (no IMU needed), handy to test the app / BLE link.
#define DEMO_MODE 0

// IMU profile used when your detector does not choose one itself (see imuProfile()).
// 0 = 416 Hz / +-8 g, 1 = 833 Hz / +-16 g.
#define IMU_USE_HIGH_RATE_PROFILE 0

#define DEBUG_SERIAL 1
#define SERIAL_BAUD 115200

// While DEBUG_SERIAL is on and DEMO_MODE is 0, print one summary line this often: how many IMU
// samples arrived and how many I2C reads failed. Useful to tell "no IMU data" apart from
// "IMU data is fine, the algorithm just isn't calling takeoff()/landing()".
#define IMU_HEARTBEAT_MS 2000UL

// ============================================================================
// Deep sleep (core/DeepSleep.h). Not used in DEMO_MODE.
// ============================================================================

// 1 = go to deep sleep when nothing happens, wake up again when the device is shaken/hit.
// While asleep the device does not advertise and cannot be flashed: wake it first (shake it or
// press reset), or hold D1 low during a reset to keep it awake.
#define DEEP_SLEEP_ENABLED 1

// Derived, do not edit: deep sleep needs the IMU as its wake-up source, which the demo does not
// use.
#define DEEP_SLEEP_ACTIVE (DEEP_SLEEP_ENABLED && !DEMO_MODE)

// Sleep after this long without a BLE connection and without a takeoff/landing.
// The device never sleeps by itself while an app is connected (the app can send it to sleep with
// the Command characteristic, see BleUuids.h).
#define SLEEP_AFTER_IDLE_MS 60000UL

// While asleep, wake up this often for a moment to ask the IMU whether it saw motion. Shorter =
// reacts faster, but uses more power.
#define SLEEP_POLL_INTERVAL_MS 3000

// How hard the device must be moved to wake up (IMU registers, see the LSM6DS3TR-C datasheet).
// The IMU compares each acceleration sample with the one before (26 Hz, so 38 ms apart).
// WAKE_UP_THS: threshold in steps of 2 g / 64 = 31 mg (0x01..0x3F). Lower = more sensitive.
// WAKE_UP_DUR: 0x00 = a single sample above the threshold wakes; 0x20/0x40/0x60 = it must stay
//              above for 1/2/3 more samples (less sensitive to short knocks).
// firmware/deep_sleep_test/ used 0x08 and 0x3F: that needs a hard hit, shaking by hand is
// often not enough.
#define IMU_WAKE_UP_THS 0x02
#define IMU_WAKE_UP_DUR 0x00

// ============================================================================
// Device identity (exposed over BLE, see BleUuids.h for the field ids)
// Every string must be at most DIS_STRING_MAX (32) bytes.
// ============================================================================

#define FIRMWARE_VERSION "0.6.0"    // Firmware Revision String; bump on every release
#define HARDWARE_REVISION "0.1"     // Hardware Revision String; change with the PCB/board
#define MANUFACTURER_NAME "OpenToF"
#define MODEL_NUMBER "OpenToF Sensor"
// Serial Number String = the BLE device address (unique per chip), set at start-up.

#define DEFAULT_DEVICE_NAME "OpenToF"
#define NAME_MAX_BYTES 20

// GAP Appearance shown by scanners. 0x0540 = Generic Sensor (0x0541 = Motion Sensor).
#define BLE_APPEARANCE 0x0540

// ============================================================================
// BLE timing. Connection interval unit 1.25 ms, advertising interval unit 0.625 ms.
// ============================================================================

#define BLE_CONN_INTERVAL_MIN 6   // 7.5 ms  (low latency for notifications)
#define BLE_CONN_INTERVAL_MAX 12  // 15 ms
#define BLE_ADV_INTERVAL 160      // 100 ms

// After a "sleep" command the connection is kept open this long before the sensor disconnects,
// so that the response to the app's write still gets out.
#define BLE_SLEEP_COMMAND_DELAY_MS 200

// ============================================================================
// Board pins (from the Seeed XIAO MG24 wiki)
// ============================================================================

#define IMU_POWER_PIN PD5
#define IMU_I2C_ADDRESS 0x6A
#define BATTERY_ENABLE_PIN PD3
#define BATTERY_SENSE_PIN PD4
#define RF_SWITCH_POWER_PIN PB5
#define RF_SWITCH_PIN PB4  // LOW = onboard antenna (as in the Seeed BLE example)

#define BATTERY_INTERVAL_MS 30000UL

// LED while waiting for the app to connect: on for ..._ON_MS, off for ..._OFF_MS, repeating.
// All LED signals are listed in firmware/README.md ("LED status").
#define LED_WAITING_ON_MS 300
#define LED_WAITING_OFF_MS 700

// ============================================================================
// Demo simulation (DEMO_MODE 1): bursts of jumps separated by rests.
// ============================================================================

#define DEMO_START_DELAY_MS 3000
#define DEMO_BURST_JUMPS 12
#define DEMO_REST_MS 6000
