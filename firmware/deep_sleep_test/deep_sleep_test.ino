// Test code for power-down/deep sleep mode of XIAO MG24 Sense
// We want to sleep until motion is detected on the IMU
// Unfortunatly, the board does not connect the IMU interupt pins
// so we have to wake up every few seconds to see if the IMU saw
// motion (by manually reading the IRQ register of the IMU)

// TODO: Can we put the Flash to powerdown? (Command 0xB9)

#include <ArduinoLowPower.h>
#include <LSM6DS3.h>

LSM6DS3Core imu(I2C_MODE, 0x6A);

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  Serial.println("Deep sleep with external or timed wakeup");
  if (LowPower.wokeUpFromDeepSleep()) {
    Serial.println("Woke up from deep sleep");
  } else {
    Serial.println("Other wakeup cause");
  }

  if (imu.beginCore() != IMU_SUCCESS) {
    Serial.println("IMU init failed!");
    while(1);
  }
  // configure IMU
  imu.writeRegister(0x12, 0x01); // CTRL_3_C = software reset
  imu.writeRegister(0x10, 0x20); // CTRL_1_XL = accel enabled with 26 Hz range 2g
  // the next two value seem to be fine. You need to hit the IMU hard to trigger it, but it will most always see it then
  imu.writeRegister(0x5B, 0x08); // WAKE_UP_DUR number of samples above threshold
  imu.writeRegister(0x5C, 0x3F); // WAKE_UP_THS threshold (max)
  imu.writeRegister(0x5E, 0x20); // MD1_CFG = wakup on INT1 (pin is not connected, but required for lateched mode!)
  imu.writeRegister(0x58, 0x81); // TAP_CFG = basic function (wakeup) enabled, latched interupt mode
  
  //TODO: Keep power pin to IMU high in deep sleep
}

void loop() {
  uint8_t wakeupSrc_reg;
  imu.readRegister(&wakeupSrc_reg, 0x1B);
  bool wakeupDetected = (wakeupSrc_reg & 0x08) != 0;
  if (wakeupDetected) {
    Serial.println("Motion detected!");
  }
  digitalWrite(LED_BUILTIN, wakeupDetected ? LED_BUILTIN_ACTIVE : LED_BUILTIN_INACTIVE);
  delay(100);

  // Serial.printf("Going to deep sleep for 5s at %lu\n", millis());
  // LowPower.deepSleep(5000);  // RAM content is lost, code will start from the beginning afterwards
}
