// Deep sleep (EM4) with wake-up on motion. Ported from firmware/deep_sleep_test/.
//
// The board does not connect the IMU's interrupt pins, so the IMU cannot wake the MCU directly.
// Instead the MCU sleeps in EM4 and a timer (BURTC) wakes it every SLEEP_POLL_INTERVAL_MS. Each
// wake-up is a reset: setup() asks the IMU whether it saw motion in the meantime (latched
// wake-up interrupt, see ImuSource::motionSinceSleep()) and, if not, sleeps again right away.
//
// Pins. The IMU has to stay powered (IMU_POWER_PIN high) while the MCU sleeps and across the
// reset that ends the sleep, otherwise it forgets both its wake-up configuration and the
// latched "motion seen" flag:
//   - EM4 is entered with pin retention "latch": every pad keeps the state it has at that moment.
//     So everything except the IMU supply must be switched to its low-power state BEFORE
//     deepSleepEnter() (done in the .ino).
//   - After the reset the GPIO registers are back at their defaults while the pads are still
//     latched. deepSleepRestorePins() runs before main(), writes "IMU_POWER_PIN = output high"
//     again and only then releases the latch, so the pin never drops.
//   - pinMode(pin, OUTPUT) of this core drives the pin low until the following digitalWrite().
//     On IMU_POWER_PIN that power-cycles the IMU. Nothing on the way from reset to the motion
//     check may call it (that rules out LSM6DS3::begin() and ImuSource::begin() there).
//
// Including ArduinoLowPower.h also adds the core's escape hatch: holding DEEP_SLEEP_ESCAPE_PIN
// (D1) low during a reset keeps the device awake with the LED on, so it can be flashed.
#pragma once

#include <Arduino.h>
#include <ArduinoLowPower.h>  // BURTC interrupt handler + escape hatch

#include "em_burtc.h"
#include "em_cmu.h"
#include "em_emu.h"
#include "em_gpio.h"
#include "em_rmu.h"

#include "../config/FirmwareConfig.h"  // DEEP_SLEEP_ACTIVE, SLEEP_POLL_INTERVAL_MS

// Runs just before main(): there is a stack, but sl_system_init() has not run yet, so only
// emlib works here (no Arduino API, no RTOS).
static void __attribute__((constructor)) deepSleepRestorePins() {
  if (RMU_ResetCauseGet() & EMU_RSTCAUSE_EM4) {
    CMU_ClockEnable(cmuClock_GPIO, true);
    GPIO_PinModeSet(gpioPortD, 5, gpioModePushPull, 1);  // IMU_POWER_PIN (PD5) = output high
  }
  EMU_UnlatchPinRetention();
}

// True if this start is a wake-up by the sleep timer. A reset button press or a power cycle
// while asleep is a normal start, so the device can always be woken by hand.
static bool wasWokenFromDeepSleep() {
  const uint32_t cause = get_system_reset_cause();
  return (cause & EMU_RSTCAUSE_EM4) && !(cause & (EMU_RSTCAUSE_PIN | EMU_RSTCAUSE_POR));
}

// Enters EM4 with all pads latched; does not return. The device restarts from the reset vector
// after SLEEP_POLL_INTERVAL_MS (RAM content is lost).
static void deepSleepEnter() {
  CMU_ClockSelectSet(cmuClock_EM4GRPACLK, cmuSelect_ULFRCO);  // 1 kHz: one tick = 1 ms
  CMU_ClockEnable(cmuClock_BURTC, true);
  CMU_ClockEnable(cmuClock_BURAM, true);

  BURTC_Init_TypeDef burtcInit = BURTC_INIT_DEFAULT;
  burtcInit.compare0Top = true;  // reset the counter when it reaches the compare value
  burtcInit.em4comp = true;      // compare match wakes from EM4 (causes a reset)
  BURTC_Init(&burtcInit);

  BURTC_CounterReset();
  BURTC_CompareSet(0, SLEEP_POLL_INTERVAL_MS);
  BURTC_IntEnable(BURTC_IEN_COMP);
  NVIC_EnableIRQ(BURTC_IRQn);
  BURTC_Enable(true);

  EMU_EM4Init_TypeDef em4Init = EMU_EM4INIT_DEFAULT;
  em4Init.pinRetentionMode = emuPinRetentionLatch;
  EMU_EM4Init(&em4Init);
  EMU_EnterEM4();
}
