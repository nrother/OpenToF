/*
 * OpenToF sensor firmware
 * Board: Seeed XIAO MG24 Sense (EFR32MG24, onboard LSM6DS3TR-C IMU)
 *
 * Arduino IDE setup
 *   Boards manager URL : https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json
 *   Board package      : "Silicon Labs" -> board "XIAO MG24 Sense"
 *   Tools > Protocol stack : "BLE (Arduino)"        (NOT "BLE (Silabs)")
 *   Libraries          : ArduinoBLE, "Seeed Arduino LSM6DS3" (>= 2.0.4); EEPROM ships with the core
 *
 * This file only wires the parts together. Each part is a header in one of three folders:
 *
 *   config/       settings you change
 *     FirmwareConfig.h      modes, version/identity strings, timing, pins
 *     BleUuids.h            BLE UUIDs (custom + Bluetooth SIG) and the protocol description
 *
 *   algorithms/   logic you write or tune (pick which one runs in the block below)
 *     MyJumpDetector.h        template/illustration, not a tuned detector
 *     StaLtaJumpDetector.h    STA/LTA envelope detector
 *     AzPipelineJumpDetector.h az-only pipeline port
 *     BatteryCurve.h          battery voltage -> percent
 *
 *   core/         plumbing (normally not edited)
 *     JumpDetector.h        interface between the IMU and your algorithm
 *     ImuTypes.h, Transition.h   data types
 *     ImuSource.h           reads the IMU and feeds the detector
 *     DemoSource.h          simulated jumps (DEMO_MODE 1)
 *     JumpEventPublisher.h  takeoff/landing reports -> BLE events (jump ids, stage rules)
 *     BleService.h          BLE GATT server (jump, battery and device information services)
 *     BatteryMonitor.h      battery measurement
 *     DeviceName.h          device name in flash + validation
 *     BootCounter.h         boot counter in flash (lets the app notice a restarted clock)
 *     Logging.h, Micros64.h helpers
 *
 * Includes are relative to the including file: this .ino uses "core/Logging.h", headers use
 * "Sibling.h" or "../core/Logging.h" (the sketch folder itself is not on the include path).
 *
 * Only setup() and loop() are in this .ino on purpose: the Arduino IDE auto-generates
 * prototypes for functions in .ino files, and that breaks when their signatures use types
 * defined in the sketch. Code in the headers is not affected.
 */

// ============================================================================
// Algorithm selection -- uncomment exactly one block (its #include AND its typedef
// line) to choose the jump-detection algorithm that gets built.
//
// To add your own: write a header with a class derived from JumpDetector (copy
// algorithms/MyJumpDetector.h and rename the class), drop it into algorithms/, and add a
// block for it here.
// ============================================================================

// #include "algorithms/MyJumpDetector.h"
// typedef MyJumpDetector ActiveJumpDetector;

// #include "algorithms/StaLtaJumpDetector.h"
// typedef StaLtaJumpDetector ActiveJumpDetector;

// #include "algorithms/AzPipelineJumpDetector.h"
// typedef AzPipelineJumpDetector ActiveJumpDetector;

// #include "algorithms/AzPipelineBufferedJumpDetector.h"
// typedef AzPipelineBufferedJumpDetector ActiveJumpDetector;

#include "algorithms/BedCycleJumpDetector.h"
typedef BedCycleJumpDetector ActiveJumpDetector;


#include "config/FirmwareConfig.h"
#include "core/BatteryMonitor.h"
#include "core/BleService.h"
#include "core/BootCounter.h"
#include "core/DemoSource.h"
#include "core/DeviceName.h"
#include "core/ImuSource.h"
#include "core/JumpEventPublisher.h"
#include "core/Logging.h"

static ActiveJumpDetector detector;
static ImuSource imuSource(detector);
static DemoSource demoSource;
static TransitionSource* source = nullptr;
static JumpEventPublisher publisher;
static BatteryMonitor battery;

static void fatalBlink(const char* message) {
  LOG(message);
  while (true) {  // fast blink forever
    digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
    delay(100);
    digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
    delay(100);
  }
}

void setup() {
#if DEBUG_SERIAL
  Serial.begin(SERIAL_BAUD);  // do not wait for a host: the device runs standalone
#endif
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  LOG(String("OpenToF firmware ") + FIRMWARE_VERSION + " (hardware " + HARDWARE_REVISION + ")");

  // Antenna switch: power it, select the onboard antenna.
  pinMode(RF_SWITCH_POWER_PIN, OUTPUT);
  digitalWrite(RF_SWITCH_POWER_PIN, HIGH);
  delay(100);
  pinMode(RF_SWITCH_PIN, OUTPUT);
  digitalWrite(RF_SWITCH_PIN, LOW);

#if DEMO_MODE
  source = &demoSource;
#else
  source = &imuSource;
#endif
  LOG(String("Algorithm: ") + source->name());

  loadDeviceName();
  incrementBootCount();
  LOG(String("Boot #") + bootCount);
  if (!bleBegin(*source)) fatalBlink("BLE init failed");

  if (battery.update(true)) bleSetBatteryLevel(battery.percent());

#if DEMO_MODE
  LOG("DEMO MODE: simulated jumps, IMU not used");
  demoSource.begin();
#else
  if (!imuSource.begin()) fatalBlink("IMU init failed");
  LOG(String("IMU profile: ") + imuSource.profile().name);
#endif

  bleStartAdvertising();
}

void loop() {
  blePoll();

  Transition t;
  while (source->poll(t)) publisher.handle(t);

  if (battery.update(false)) bleSetBatteryLevel(battery.percent());

  flushDeviceName();
}
