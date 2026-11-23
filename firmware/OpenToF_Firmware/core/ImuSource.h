// IMU source: samples the LSM6DS3 FIFO and feeds the active JumpDetector.
#pragma once

#include <Arduino.h>
#include <LSM6DS3.h>
#include <Wire.h>

#include "../config/FirmwareConfig.h"
#include "ImuSampleSource.h"

#define IMU_SAMPLE_RATE_HZ 416

class ImuSource : public ImuSampleSource {
 public:
  explicit ImuSource(JumpDetector& detector)
      : ImuSampleSource(detector), _imu(I2C_MODE, IMU_I2C_ADDRESS) {}

  bool begin() {
    pinMode(IMU_POWER_PIN, OUTPUT);
    digitalWrite(IMU_POWER_PIN, HIGH);  // turn the IMU on

    // Configure the IMU
    _imu.settings.gyroEnabled = 1;
    _imu.settings.gyroRange = 2000; //max deg/s
    _imu.settings.gyroBandWidth = 400; //Hz
    _imu.settings.gyroSampleRate = IMU_SAMPLE_RATE_HZ;

    _imu.settings.accelEnabled = 1;
    _imu.settings.accelRange = 16; //max g
    _imu.settings.accelBandWidth = 400; //Hz
    _imu.settings.accelSampleRate = IMU_SAMPLE_RATE_HZ;

    // Include both sensors in the FIFO.
    _imu.settings.gyroFifoEnabled = 1;
    _imu.settings.gyroFifoDecimation = 1;

    _imu.settings.accelFifoEnabled = 1;
    _imu.settings.accelFifoDecimation = 1;

    // FIFO configuration.
    _imu.settings.fifoSampleRate = IMU_SAMPLE_RATE_HZ;
    _imu.settings.fifoModeWord = 6; // continuous
    _imu.settings.fifoThreshold = 512;

    // Temperature is unnecessary
    _imu.settings.tempEnabled = 0;

    if (_imu.begin() != 0) return false;

    // set I2C to 400 kHz. Must be called after myIMU.begin()!
    Wire1.setClock(400000);

    _imu.fifoBegin();

    // workaround, the library always enables dataset 3 and 4
    _imu.writeRegister(LSM6DS3_ACC_GYRO_FIFO_CTRL4, 0);

    // wait a bit for everything to settle
    delay(10);

    // clear the FIFO, we are ready to go
    _imu.fifoClear();

    _sampleCount = 0;
    _lastSampleUs = 0;
    beginSamples();
    return true;
  }

  // ---- Deep sleep ----

  // Switches the IMU from measuring to its low-power "wake-up" function: accelerometer only at
  // 26 Hz, and a latched interrupt flag that is set once the acceleration changes by more than
  // the threshold. Call right before deep sleep; begin() is needed to measure again.
  // Returns false if the IMU did not take the configuration
  bool armWakeOnMotion() {
    bool ok = writeReg(0x12, 0x01);  // CTRL3_C: software reset
    ok = ok && writeReg(0x10, 0x20);             // CTRL1_XL: accel 26 Hz, +-2 g (gyro stays off)
    ok = ok && writeReg(0x5B, IMU_WAKE_UP_THS);  // WAKE_UP_THS
    ok = ok && writeReg(0x5C, IMU_WAKE_UP_DUR);  // WAKE_UP_DUR
    ok = ok && writeReg(0x5E, 0x20);  // MD1_CFG: wake-up on INT1 (pin not connected, but
                                      // required for the latched mode)
    ok = ok && writeReg(0x58, 0x81);  // TAP_CFG: interrupts enabled, latched
    delay(200);                       // let the filter settle on gravity...
    uint8_t src;
    return ok && _imu.readRegister(&src, 0x1B) == IMU_SUCCESS;  // ...and clear the flag it set
  }

  // After a wake-up from deep sleep: true if the IMU saw motion since armWakeOnMotion() (reading
  // the flag clears it). Also true if the IMU does not answer, so that the caller does a normal
  // start instead of sleeping without a working wake-up source.
  bool motionSinceSleep() {
    // We cannot use _imu.begin() here: This calls pinMode(OUTPUT) on the power-pin which causes
    // the pin to glitch to LOW (see bug https://github.com/SiliconLabsSoftware/arduino/issues/209)
    // This is not a real problem: The only other thing that _imu.begin() does it calling Wire1.begin(),
    // which we can do here
    Wire1.begin();
    uint8_t value;
    if (_imu.readRegister(&value, 0x0F) != IMU_SUCCESS || value != 0x6A) return true;  // WHO_AM_I
    if (_imu.readRegister(&value, 0x1B) != IMU_SUCCESS) return true;                   // WAKE_UP_SRC
    return (value & 0x08) != 0;                                                        // WU_IA
  }

  bool poll(Transition& out) override {
    // First hand out anything the detector reported earlier.
    if (nextTransition(out)) return true;

    // Poll the FIFO
    int16_t status = _imu.fifoGetStatus();
    uint16_t words = status & 0x07FF;
#if DEBUG_SERIAL
    heartbeat("IMU", "last FIFO level = ", words);
#endif

    while (words >= IMU_WORDS_PER_SAMPLE) {
      RawImuSample sample;
      if (!readSample(sample)) {
        noteReadFailure();
        return false;
      }
      const float dt = 1.0f / IMU_SAMPLE_RATE_HZ;
      _sampleCount++;
      _lastSampleUs = (_sampleCount * 1000000ULL) / IMU_SAMPLE_RATE_HZ;
      processSample(sample, _lastSampleUs, dt);

      words -= IMU_WORDS_PER_SAMPLE;
    }
    return nextTransition(out);
  }

 private:
  LSM6DS3 _imu;
  uint64_t _sampleCount = 0;
  uint64_t _lastSampleUs = 0;

  bool writeReg(uint8_t offset, uint8_t value) { return _imu.writeRegister(offset, value) == IMU_SUCCESS; }

  // Native data format coming from the IMU
  static constexpr int IMU_WORDS_PER_SAMPLE = 6;

  bool readSample(RawImuSample& sample) {
    // One complete gyro + accel sample
    if (_imu.readRegisterRegion(reinterpret_cast<uint8_t *>(&sample), LSM6DS3_ACC_GYRO_FIFO_DATA_OUT_L, sizeof(sample)) != IMU_SUCCESS) return false;
    return true;
  }
};
