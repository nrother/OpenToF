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

// 1 = print every IMU sample as CSV over Serial (for looking at real data and tuning).
// Columns: t_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps   Text messages start with "# ".
// Print only every Nth sample; 1 = every sample needs a much higher SERIAL_BAUD
// (833 Hz * ~45 bytes = ~37 kB/s -> use 921600 and set the same in the Serial Monitor).
#define IMU_SERIAL_LOG 0
#define IMU_SERIAL_LOG_EVERY_N 8

#define DEBUG_SERIAL 1
#define SERIAL_BAUD 115200

// While DEBUG_SERIAL is on and DEMO_MODE is 0, print one summary line this often: how many IMU
// samples arrived and how many I2C reads failed. Useful to tell "no IMU data" apart from
// "IMU data is fine, the algorithm just isn't calling takeoff()/landing()".
#define IMU_HEARTBEAT_MS 2000UL

// ============================================================================
// Device identity (exposed over BLE, see BleUuids.h for the field ids)
// Every string must be at most DIS_STRING_MAX (32) bytes.
// ============================================================================

#define FIRMWARE_VERSION "0.4.0"    // Firmware Revision String; bump on every release
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

#ifndef LED_BUILTIN_ACTIVE
#define LED_BUILTIN_ACTIVE LOW
#endif
#ifndef LED_BUILTIN_INACTIVE
#define LED_BUILTIN_INACTIVE (!LED_BUILTIN_ACTIVE)
#endif

// ============================================================================
// Demo simulation (DEMO_MODE 1): bursts of jumps separated by rests.
// ============================================================================

#define DEMO_START_DELAY_MS 3000
#define DEMO_BURST_JUMPS 12
#define DEMO_REST_MS 6000
