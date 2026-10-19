/*
 * OpenToF sensor firmware
 * Board: Seeed XIAO MG24 Sense (EFR32MG24, onboard LSM6DS3TR-C IMU)
 *
 * Arduino IDE setup
 *   Boards manager URL : https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json
 *   Board package      : "Silicon Labs" -> board "XIAO MG24 Sense"
 *   Tools > Protocol stack : "BLE (Arduino)"        (NOT "BLE (Silabs)")
 *   Libraries          : ArduinoBLE, "Seeed Arduino LSM6DS3" (>= 2.0.4)
 */

// ============================================================================
// Algorithm selection -- uncomment exactly one block to choose the
// jump-detection algorithm that gets built.
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
#include "core/DeepSleep.h"
#include "core/DemoSource.h"
#include "core/DeviceName.h"
#include "core/ImuSource.h"
#include "core/JumpEventPublisher.h"
#include "core/Logging.h"

static ActiveJumpDetector detector;
static ImuSource imuSource(detector);
#if DEMO_MODE
static DemoSource demoSource;
#endif
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

// Blinks the LED `times` times (`ms` on, `ms` off) and leaves it off.
static void blinkLed(int times, int ms) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
    delay(ms);
    digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
    delay(ms);
  }
}

// Update the LED: steady on while an app is connected, slow blinking while waiting
// for connection. Must be called once per loop()
static void updateStatusLed() {
  static bool wasOn = false;
  const bool on = bleConnected() ||
                  millis() % (LED_WAITING_ON_MS + LED_WAITING_OFF_MS) < LED_WAITING_ON_MS;
  if (on == wasOn) return;
  wasOn = on;
  digitalWrite(LED_BUILTIN, on ? LED_BUILTIN_ACTIVE : LED_BUILTIN_INACTIVE);
}

#if DEEP_SLEEP_ACTIVE
// Goes to deep sleep now; a connected app is disconnected first. Returns only if the IMU could
// not be set up as the wake-up source.
static void sleepNow() {
  bleDisconnect();
  if (!imuSource.armWakeOnMotion()) {
    // Without a working wake-up source the device would sleep forever: stay awake instead.
    if (!imuSource.begin()) fatalBlink("IMU wake-up setup failed");
    return;
  }
  bleEnd();
  blinkLed(6, 150);  // going to sleep now

  // Every pad keeps its current state during the sleep (see DeepSleep.h). The IMU will be
  // powered, but everything else should be off.
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  digitalWrite(BATTERY_ENABLE_PIN, LOW);
  digitalWrite(RF_SWITCH_POWER_PIN, LOW);
#if DEBUG_SERIAL
  Serial.flush();
#endif

  deepSleepEnter();
}

// Go to deep sleep when the app asks for it, or after SLEEP_AFTER_IDLE_MS without a BLE
// connection and without a takeoff/landing (`activity = true`). Must be called once per loop().
static void sleepWhenIdleOrAsked(bool activity) {
  static uint32_t lastActiveMs = 0;
  if (activity || bleConnected()) lastActiveMs = millis();

  if (bleTakeSleepRequest()) {
    LOG("Sleep command, going to deep sleep");
  } else if (millis() - lastActiveMs >= SLEEP_AFTER_IDLE_MS) {
    LOG("Idle, going to deep sleep");
  } else {
    return;
  }
  sleepNow();
  lastActiveMs = millis();  // still awake (sleep failed): try again after a full idle time
}
#endif

void setup() {
#if DEEP_SLEEP_ACTIVE
  // Woken by the sleep timer: only ask the IMU for motion and sleep again if there was none.
  // This should be as fast as possible to save power
  const bool wokenFromDeepSleep = deepSleepWokenFromDeepSleep();
  if (wokenFromDeepSleep && !imuSource.motionSinceSleep()) deepSleepEnter();
#endif

#if DEBUG_SERIAL
  Serial.begin(SERIAL_BAUD);
#endif
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  LOG(String("OpenToF firmware ") + FIRMWARE_VERSION + " (hardware " + HARDWARE_REVISION + ")");
#if DEEP_SLEEP_ACTIVE
  if (wokenFromDeepSleep) {
    LOG("Woke up from deep sleep: motion detected");
    blinkLed(3, 80);  // show that the shake was noticed
  }
#endif

  // Antenna switch: select the onboard antenna, activate switch
  pinMode(RF_SWITCH_PIN, OUTPUT);
  digitalWrite(RF_SWITCH_PIN, LOW);
  pinMode(RF_SWITCH_POWER_PIN, OUTPUT);
  digitalWrite(RF_SWITCH_POWER_PIN, HIGH);

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

  bool activity = false;
  Transition t;
  while (source->poll(t)) {
    publisher.handle(t);
    activity = true;
  }

  if (battery.update(false)) bleSetBatteryLevel(battery.percent());

  updateStatusLed();

#if DEEP_SLEEP_ACTIVE
  sleepWhenIdleOrAsked(activity);
#endif
}
