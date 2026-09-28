// Test code for power-down/deep sleep mode of XIAO MG24 Sense
// We want to sleep until motion is detected on the IMU
// Unfortunatly, the board does not connect the IMU interupt pins
// so we have to wake up every few seconds to see if the IMU saw
// motion (by manually reading the IRQ register of the IMU)

// TODO: Can we put the Flash to powerdown? (Command 0xB9)

#include <ArduinoLowPower.h>
#include <LSM6DS3.h>
#include <Wire.h>

#include "em_rmu.h"
#include "em_cmu.h"
#include "em_gpio.h"
#include "em_i2c.h"
#include "em_emu.h"
#include "em_burtc.h"

constexpr int IMU_I2C_ADDR = 0x6A;
LSM6DS3Core imu(I2C_MODE, IMU_I2C_ADDR);

bool no_wakeup = false;
bool who_am_i_failed = false;
bool wakeup_seen = false;

// This functions run just before main(). The CRT is stable, we have a stack,
// but sl_system_init() has not been called, so only emlib is available, no RTOS
// or high-level drivers.
// If we are waking up from EM4 the GPIOs are still latched.
void __attribute__((constructor)) before_main() {
  // check reset cause
  uint32_t rstCause = RMU_ResetCauseGet();
  if ((rstCause & EMU_RSTCAUSE_EM4) == 0) {
    // not EM4 wakeup -> unlatch pins and do normal startup
    EMU_UnlatchPinRetention();
    no_wakeup = true;
    return;
  }

  // ok, we woke up from EM4. Restore GPIO config and unlatch
  restore_gpio();

  // test: early I2C does not work, continue to normal startup
  return;

  init_i2c_early();

  // read "who am I" register to check IMU communication
  uint8_t who_am_i = read_imu_register_early(0x0F);
  if (who_am_i != 0x6A) {
    // something is broken, continue with normal startup
    who_am_i_failed = true;
    return;
  }

  // read "wakup detected" flag from IMU
  uint8_t wakeupSrc_reg = read_imu_register_early(0x1B);
  bool wakeupDetected = (wakeupSrc_reg & 0x08) != 0;
  if (wakeupDetected) {
    // we saw motion, time to wake up. Continue normal startup
    wakeup_seen = true;
    return;
  }

  // no motion, sleep again
  deepSleepLatch(3000);
}

void restore_gpio(void) {
  CMU_ClockEnable(cmuClock_GPIO, true);

  // restore GPIO config:
  GPIO_PinModeSet(gpioPortD, 5, gpioModePushPull, 1);  // PD5 = output high -> enable IMU power
  GPIO_PinModeSet(gpioPortA, 7, gpioModePushPull, 0);  // PA7 = output low -> enable LED (test)

  // unlatch GPIOs
  EMU_UnlatchPinRetention();
}

void init_i2c_early(void) {
  CMU_ClockEnable(cmuClock_I2C1, true);

  // configure I2C1
  GPIO_PinModeSet(gpioPortB, 2, gpioModeWiredAndPullUpFilter, 1);
  GPIO_PinModeSet(gpioPortB, 3, gpioModeWiredAndPullUpFilter, 1);
  // note: SDA/SCL is swapped in overview diagram!
  GPIO->I2CROUTE[1].SCLROUTE = (gpioPortB << _GPIO_I2C_SCLROUTE_PORT_SHIFT) | (3 << _GPIO_I2C_SCLROUTE_PIN_SHIFT);  // PB3 = SCL
  GPIO->I2CROUTE[1].SDAROUTE = (gpioPortB << _GPIO_I2C_SDAROUTE_PORT_SHIFT) | (2 << _GPIO_I2C_SDAROUTE_PIN_SHIFT);  // PB2 = SDA
  GPIO->I2CROUTE[1].ROUTEEN = GPIO_I2C_ROUTEEN_SCLPEN | GPIO_I2C_ROUTEEN_SDAPEN;

  I2C_Reset(I2C1);

  I2C_Init_TypeDef i2cInit = I2C_INIT_DEFAULT;
  i2cInit.master = true;
  i2cInit.freq = I2C_FREQ_STANDARD_MAX;

  I2C_Init(I2C1, &i2cInit);
}

uint8_t read_imu_register_early(uint8_t reg_addr) {
  uint8_t rx_buffer = 0;
  I2C_TransferSeq_TypeDef seq;
  seq.addr = IMU_I2C_ADDR << 1;
  seq.flags = I2C_FLAG_WRITE_READ;
  seq.buf[0].data = &reg_addr;
  seq.buf[0].len = 1;
  seq.buf[1].data = &rx_buffer;
  seq.buf[1].len = 1;

  I2C_TransferReturn_TypeDef ret = I2C_TransferInit(I2C1, &seq);
  while (ret == i2cTransferInProgress) {
    ret = I2C_Transfer(I2C1);  // TODO: This currently hangs here :/
  }
  return rx_buffer;
}

void deepSleepLatch(uint32_t millis) {
  CMU_ClockSelectSet(cmuClock_EM4GRPACLK, cmuSelect_ULFRCO);
  CMU_ClockEnable(cmuClock_BURTC, true);
  CMU_ClockEnable(cmuClock_BURAM, true);

  BURTC_Init_TypeDef burtcInit = BURTC_INIT_DEFAULT;
  burtcInit.compare0Top = true;  // Reset counter when counter reaches compare value
  burtcInit.em4comp = true;      // BURTC compare interrupt wakes from EM4 (causes reset)
  BURTC_Init(&burtcInit);

  BURTC_CounterReset();
  BURTC_CompareSet(0, millis);

  BURTC_IntEnable(BURTC_IEN_COMP);  // Compare match
  NVIC_EnableIRQ(BURTC_IRQn);
  BURTC_Enable(true);

  // this->setupDeepSleepWakeUpPin();

  EMU_EM4Init_TypeDef em4_init = EMU_EM4INIT_DEFAULT;

  // em4_init.pinRetentionMode = emuPinRetentionEm4Exit;// will disable LED on boot
  em4_init.pinRetentionMode = emuPinRetentionLatch;

  EMU_EM4Init(&em4_init);
  EMU_EnterEM4();
}

void setup() {
  // do normal startup, either hard-reset or motion was detected
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
  Serial.println("Deep sleep with external or timed wakeup");
  Serial.print("Flags: no_wakup: ");
  Serial.print(no_wakeup);
  Serial.print("who_am_i_failed: ");
  Serial.print(who_am_i_failed);
  Serial.print("wakeup_seen: ");
  Serial.print(wakeup_seen);
  Serial.println();
  if (LowPower.wokeUpFromDeepSleep()) {
    Serial.println("Woke up from deep sleep");
    check_wakeup_late();
  } else {
    Serial.println("Other wakeup cause");
  }

  if (imu.beginCore() != IMU_SUCCESS) {
    Serial.println("IMU init failed!");
    while (1)
      ;
  }
  // configure IMU
  imu.writeRegister(0x12, 0x01);  // CTRL_3_C = software reset
  imu.writeRegister(0x10, 0x20);  // CTRL_1_XL = accel enabled with 26 Hz range 2g
  // the next two value seem to be fine. You need to hit the IMU hard to trigger it, but it will most always see it then
  imu.writeRegister(0x5B, 0x08);  // WAKE_UP_DUR number of samples above threshold
  imu.writeRegister(0x5C, 0x3F);  // WAKE_UP_THS threshold (max)
  imu.writeRegister(0x5E, 0x20);  // MD1_CFG = wakup on INT1 (pin is not connected, but required for lateched mode!)
  imu.writeRegister(0x58, 0x81);  // TAP_CFG = basic function (wakeup) enabled, latched interupt mode

  for (int i = 0; i < 10; i++) {
    Serial.print("Awake...");
    Serial.println(10 - i);
    delay(1000);
  }

  uint8_t wakeupSrc_reg;
  imu.readRegister(&wakeupSrc_reg, 0x1B);
  bool wakeupDetected = (wakeupSrc_reg & 0x08) != 0;
  if (wakeupDetected) {
    Serial.println("MOTION!!!!!!!");
  }

  Serial.println("Going to sleep for 3 sec...");
  deepSleepLatch(3000);
}

void check_wakeup_late(void) {
  imu.beginCore();

  // read who am I
  uint8_t whoami_reg;
  imu.readRegister(&whoami_reg, 0x0F);
  Serial.print("WhoAmI = ");
  Serial.println(whoami_reg, HEX);

  // read "wakup detected" flag from IMU
  uint8_t wakeupSrc_reg;
  imu.readRegister(&wakeupSrc_reg, 0x1B);
  bool wakeupDetected = (wakeupSrc_reg & 0x08) != 0;
  if (wakeupDetected) {
    // we saw motion, time to wake up. Continue normal startup
    wakeup_seen = true;
    Serial.println("MOTION!!!!!!!"); // this is never triggered. Maybe the IMU is somehow reset in deep sleep?
    return;
  }

  Serial.println("No motion, sleep again");
  // no motion, sleep again
  deepSleepLatch(3000);
}

void loop() {
}
