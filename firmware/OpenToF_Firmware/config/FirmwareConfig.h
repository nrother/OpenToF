// All settings of the firmware
#pragma once

// ============================================================================
// Modes
// ============================================================================

// 0 = use the real IMU + the active jump detector (picked at the top of the .ino).
// 1 = simulate jumps instead
#define DEMO_MODE 0

#define DEBUG_SERIAL 1
#define SERIAL_BAUD 115200

// While DEBUG_SERIAL is on and DEMO_MODE is 0, print one summary line this often: how many IMU
// samples arrived and how many I2C reads failed.
// #define IMU_HEARTBEAT_MS 2000UL
#define IMU_HEARTBEAT_MS 1000UL

// ============================================================================
// Deep sleep. Not used in DEMO_MODE.
// ============================================================================

// 1 = go to deep sleep when nothing happens, wake up again when the device is shaken/hit.
#define DEEP_SLEEP_ENABLED 1

#define DEEP_SLEEP_ACTIVE (DEEP_SLEEP_ENABLED && !DEMO_MODE)

// Sleep after this long without a BLE connection and without a takeoff/landing.
#define SLEEP_AFTER_IDLE_MS 60000UL

// While asleep, wake up this often to ask the IMU whether it saw motion.
#define SLEEP_POLL_INTERVAL_MS 3000

// How hard the device must be moved to wake up (IMU registers, see the LSM6DS3TR-C datasheet).
// WAKE_UP_THS: threshold in steps of 2 g / 64 = 31 mg (0x01..0x3F). Lower = more sensitive.
// WAKE_UP_DUR: 0x00 = a single sample above the threshold wakes; 0x20/0x40/0x60 = it must stay
//              above for 1/2/3 more samples (less sensitive to short knocks).
#define IMU_WAKE_UP_THS 0x02
#define IMU_WAKE_UP_DUR 0x00

// ============================================================================
// Device identity (exposed over BLE)
// Every string must be at most DIS_STRING_MAX (32) bytes.
// ============================================================================

#define FIRMWARE_VERSION "0.6.0"    // Firmware Revision String; bump on every release
#define HARDWARE_REVISION "0.1"     // Hardware Revision String; change with the PCB/board
#define MANUFACTURER_NAME "OpenToF"
#define MODEL_NUMBER "OpenToF Sensor"
// Serial Number String = the BLE device address (unique per chip), set at start-up.

#define DEFAULT_DEVICE_NAME "OpenToF" // the last four chars of the serial are automatically added
#define NAME_MAX_BYTES 20

// GAP Appearance shown by scanners. 0x0540 = Generic Sensor.
#define BLE_APPEARANCE 0x0540

// ============================================================================
// BLE timing. Connection interval unit 1.25 ms, advertising interval unit 0.625 ms.
// ============================================================================

#define BLE_CONN_INTERVAL_MIN 6   // 7.5 ms  (low latency for notifications)
#define BLE_CONN_INTERVAL_MAX 12  // 15 ms
#define BLE_ADV_INTERVAL 160      // 100 ms

// ============================================================================
// Board pins (for Seeed XIAO MG24)
// ============================================================================

#define IMU_POWER_PIN PD5
#define IMU_I2C_ADDRESS 0x6A
#define BATTERY_ENABLE_ADC_PIN PD3
#define BATTERY_SENSE_PIN PD4
#define RF_SWITCH_POWER_PIN PB5
#define RF_SWITCH_PIN PB4  // LOW = onboard antenna

#define BATTERY_INTERVAL_MS 30000UL

// LED while waiting for the app to connect: on for ..._ON_MS, off for ..._OFF_MS, repeating.
#define LED_WAITING_ON_MS 300
#define LED_WAITING_OFF_MS 700

// ============================================================================
// Demo simulation (DEMO_MODE 1): bursts of jumps separated by rests.
// ============================================================================

#define DEMO_START_DELAY_MS 3000
#define DEMO_BURST_JUMPS 12
#define DEMO_REST_MS 6000
