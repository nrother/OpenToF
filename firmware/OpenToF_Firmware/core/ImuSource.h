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

    _imu.settings.gyroEnabled = 1;
    _imu.settings.gyroRange = 500;
    _imu.settings.gyroSampleRate = 416;
    _imu.settings.accelEnabled = 1;
    _imu.settings.accelRange = 16;
    _imu.settings.accelSampleRate = 416;
    _imu.settings.accelBandWidth = 400;
    _imu.settings.tempEnabled = 0;

    _odrHz = 416;

    if (_imu.begin() != 0) return false;

    _periodUs = 1000000UL / 416;
    _nextSampleUs = micros() + _periodUs;
    _lastSampleUs = 0;
    _logCounter = 0;
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

    // Fixed-rate sampling with micros(). Jitter from BLE.poll() can shift sample times by a
    // few ms. If the algorithm needs exact timing, switch to the IMU data-ready interrupt
    // or FIFO with hardware timestamps.
    if ((int32_t)(micros() - _nextSampleUs) < 0) return false;
    _nextSampleUs += _periodUs;
    if ((int32_t)(micros() - _nextSampleUs) > (int32_t)(5 * _periodUs)) {
      _nextSampleUs = micros() + _periodUs;  // fell far behind: resync
    }

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
    return _detector.nextTransition(out);
  }

 private:
  JumpDetector& _detector;
  LSM6DS3 _imu;
  uint32_t _odrHz;
  uint32_t _periodUs = 2404;
  uint32_t _nextSampleUs = 0;
  uint64_t _lastSampleUs = 0;
  uint16_t _logCounter = 0;

#if DEBUG_SERIAL
  uint32_t _heartbeatAtMs = 0;
  uint32_t _samplesSinceHeartbeat = 0;
  uint32_t _i2cFailuresSinceHeartbeat = 0;

  // Prints "IMU: N samples in 2 s (~416 Hz, profile 416 Hz), M I2C read failures" every
  // IMU_HEARTBEAT_MS, so a stalled IMU shows up even if you never watch the raw data.
  void heartbeat() {
    if ((int32_t)(millis() - _heartbeatAtMs) < 0) return;
    _heartbeatAtMs = millis() + IMU_HEARTBEAT_MS;

    String line = String("IMU: ") + _samplesSinceHeartbeat + " samples in " +
                  (IMU_HEARTBEAT_MS / 1000) + " s (~" +
                  (_samplesSinceHeartbeat * 1000UL / IMU_HEARTBEAT_MS) + " Hz, profile " +
                  _odrHz + " Hz)";
    if (_i2cFailuresSinceHeartbeat > 0) {
      line += String(", ") + _i2cFailuresSinceHeartbeat + " I2C read failures";
    }
    if (_samplesSinceHeartbeat == 0) {
      line += "  !! NO DATA -- check wiring, IMU_POWER_PIN, IMU_I2C_ADDRESS";
    }
    LOG(line);

    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
  }
#endif

  // Reads one axis register pair (e.g. OUTX_L_G/OUTX_H_G) via the library's own
  // readRegisterInt16(), the exact call the library's readFloatAccelX()/readFloatGyroX() etc.
  // use internally. Returns false (and leaves *out untouched) on an I2C error.
  //
  // We used to do this as a single 12-byte burst read (gyro X..Z + accel X..Z in one
  // transaction from register 0x22). That silently failed 100% of the time on real hardware
  // (confirmed with a live I2C scan and a side-by-side comparison against these exact library
  // calls on the same bus) even though the addresses, power-up sequence and I2C clock were all
  // correct -- six separate 2-byte reads, as the library itself always does, do not have that
  // problem. Six transactions instead of one costs a bit of I2C time (well under the sample
  // period even at 833 Hz), which is the trade-off for using the proven-working access pattern.
  bool readRegPair(uint8_t offset, int16_t& out) { return _imu.readRegisterInt16(&out, offset) == IMU_SUCCESS; }

  bool writeReg(uint8_t offset, uint8_t value) { return _imu.writeRegister(offset, value) == IMU_SUCCESS; }

  bool readSample(ImuData& d) {
    int16_t gx, gy, gz, ax, ay, az;
    if (!readRegPair(0x22, gx)) return false;  // OUTX_L_G
    if (!readRegPair(0x24, gy)) return false;  // OUTY_L_G
    if (!readRegPair(0x26, gz)) return false;  // OUTZ_L_G
    if (!readRegPair(0x28, ax)) return false;  // OUTX_L_XL
    if (!readRegPair(0x2A, ay)) return false;  // OUTY_L_XL
    if (!readRegPair(0x2C, az)) return false;  // OUTZ_L_XL

    const uint64_t t = micros64();
    d.timeUs = t;
    d.dt = _lastSampleUs ? (float)(t - _lastSampleUs) * 1e-6f : 1.0f / _odrHz;
    _lastSampleUs = t;

    const float gScale = _profile->gyroMdpsPerLsb / 1000.0f;
    d.gx = gx * gScale;
    d.gy = gy * gScale;
    d.gz = gz * gScale;
    d.ax = ax / _profile->accelLsbPerG;
    d.ay = ay / _profile->accelLsbPerG;
    d.az = az / _profile->accelLsbPerG;
    return true;
  }
};
