// IMU source: samples the LSM6DS3 at 433 Hz and feeds the active JumpDetector.
#pragma once

#include <Arduino.h>
#include <LSM6DS3.h>
#include <Wire.h>

#include "../config/FirmwareConfig.h"
#include "ImuTypes.h"
#include "JumpDetector.h"
#include "Logging.h"
#include "Micros64.h"
#include "Transition.h"

class ImuSource : public TransitionSource {
 public:
  explicit ImuSource(JumpDetector& detector)
      : _detector(detector), _imu(I2C_MODE, IMU_I2C_ADDRESS) {}

  bool begin() {
    pinMode(IMU_POWER_PIN, OUTPUT);
    digitalWrite(IMU_POWER_PIN, HIGH);  // turn the IMU on

    // Configure the IMU
    _imu.settings.gyroEnabled = 1;
    _imu.settings.gyroRange = 2000; //max deg/s
    _imu.settings.gyroBandWidth = 400; //Hz
    _imu.settings.gyroSampleRate = 416;

    _imu.settings.accelEnabled = 1;
    _imu.settings.accelRange = 16; //max g
    _imu.settings.accelBandWidth = 400; //Hz
    _imu.settings.accelSampleRate = 416;

    // Include both sensors in the FIFO.
    _imu.settings.gyroFifoEnabled = 1;
    _imu.settings.gyroFifoDecimation = 1;

    _imu.settings.accelFifoEnabled = 1;
    _imu.settings.accelFifoDecimation = 1;

    // _imu.settings.timestampFifoEnabled = 1;

    // FIFO configuration.
    _imu.settings.fifoSampleRate = 400; //this is 416 Hz but this is the config constant used in the library
    _imu.settings.fifoModeWord = 6; // continuous
    _imu.settings.fifoThreshold = 512;

    // Temperature is unnecessary
    _imu.settings.tempEnabled = 0;

    _odrHz = 416;

    if (_imu.begin() != 0) return false;

    _imu.fifoBegin();

    // workarround
    // TODO: Do we still need this?
    _imu.writeRegister(LSM6DS3_ACC_GYRO_FIFO_CTRL4, 0); // disable dataset 3 and 4

    // wait a bit for everything to settle
    delay(10);

    // clear the FIFO, we are ready to go
    _imu.fifoClear();

#if DEBUG_SERIAL
    _heartbeatAtMs = millis() + IMU_HEARTBEAT_MS;
    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
#endif
    _detector.begin();
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

  const char* name() const override { return _detector.name(); }
  const char* fieldsJson() const override { return _detector.fieldsJson(); }
  const char* reasonsJson() const override { return _detector.reasonsJson(); }
  const char* confidenceKind() const override { return _detector.confidenceKind(); }

  bool poll(Transition& out) override {
#if DEBUG_SERIAL
    heartbeat();
#endif

    // First hand out anything the detector reported earlier.
    if (_detector.nextTransition(out)) return true;

    // Poll the FIFO
    int16_t status = _imu.fifoGetStatus();
    uint16_t words = status & 0x07FF;
    _lastFifoLevel = words;
    
    while (words >= IMU_WORDS_PER_SAMPLE) {
      ImuData d;
      if (!readSample(d)) {
  #if DEBUG_SERIAL
        _i2cFailuresSinceHeartbeat++;
  #endif
        return false;
      }
  #if DEBUG_SERIAL
      _samplesSinceHeartbeat++;
  #endif
      _detector.onSample(d);

      words -= IMU_WORDS_PER_SAMPLE;
    }
    return _detector.nextTransition(out);
  }

  void clearFifo() {
    _imu.fifoClear();
  }

 private:
  JumpDetector& _detector;
  LSM6DS3 _imu;
  uint32_t _odrHz;
  uint64_t _lastSampleUs = 0;

#if DEBUG_SERIAL
  uint32_t _heartbeatAtMs = 0;
  uint32_t _samplesSinceHeartbeat = 0;
  uint32_t _i2cFailuresSinceHeartbeat = 0;
  uint32_t _lastFifoLevel = 0;

  // Prints "IMU: N samples in 2 s (~416 Hz, profile 416 Hz), last FIFO level = M, O I2C read failures" every
  // IMU_HEARTBEAT_MS, so a stalled IMU shows up even if you never watch the raw data.
  void heartbeat() {
    if ((int32_t)(millis() - _heartbeatAtMs) < 0) return;
    _heartbeatAtMs = millis() + IMU_HEARTBEAT_MS;

    String line = String("IMU: ") + _samplesSinceHeartbeat + " samples in " +
                  (IMU_HEARTBEAT_MS / 1000) + " s (~" +
                  (_samplesSinceHeartbeat * 1000UL / IMU_HEARTBEAT_MS) + " Hz, target " +
                  _odrHz + " Hz), last FIFO level = " + _lastFifoLevel;
    if (_i2cFailuresSinceHeartbeat > 0) {
      line += String(", ") + _i2cFailuresSinceHeartbeat + " I2C read failures";
    }
    
    LOG(line);

    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
  }
#endif

  bool writeReg(uint8_t offset, uint8_t value) { return _imu.writeRegister(offset, value) == IMU_SUCCESS; }

  // Native data format coming from the IMU
  struct __attribute__((packed)) ImuSampleNative
  {
    int16_t gx;
    int16_t gy;
    int16_t gz;
    int16_t ax;
    int16_t ay;
    int16_t az;
  };

  static constexpr int IMU_WORDS_PER_SAMPLE = 6;
  static_assert(sizeof(ImuSampleNative) == 2 * IMU_WORDS_PER_SAMPLE, "Unexpected packet size");

  bool readSample(ImuData& d) {
    // One complete gyro + accel sample
    ImuSampleNative sample;
    if (_imu.readRegisterRegion(
      reinterpret_cast<uint8_t *>(&sample),
      LSM6DS3_ACC_GYRO_FIFO_DATA_OUT_L,
      sizeof(sample)
    ) != IMU_SUCCESS) return false;

    // the timing of the samples is fixed by the IMU hardware
    const float dt = 1.0f / _odrHz;
    d.dt = dt;
    _lastSampleUs += dt;
    d.timeUs = _lastSampleUs;

    // TODO: Check the scales
    const float gScale = 4.375f / 1000.0f;
    d.gx = sample.gx * gScale;
    d.gy = sample.gy * gScale;
    d.gz = sample.gz * gScale;
    d.ax = sample.ax / 2048.0f;
    d.ay = sample.ay / 2048.0f;
    d.az = sample.az / 2048.0f;
    return true;
  }
};
