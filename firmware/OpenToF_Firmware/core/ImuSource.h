// IMU source: samples the LSM6DS3 at the profile's rate and feeds the active JumpDetector.
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
    _profile = &_detector.imuProfile();

    pinMode(IMU_POWER_PIN, OUTPUT);
    digitalWrite(IMU_POWER_PIN, HIGH);  // the IMU only answers once PD5 powers it
    delay(20);
    Wire.begin();

    // Fast I2C, set here (before _imu.begin(), which does its own I2C traffic) to match
    // firmware/datalogger/datalogger.ino, a minimal known-working reference sketch for this
    // exact board. NOTE: this ordering was once suspected to be the fix for a "no IMU data"
    // bug; it wasn't (see readRegPair() below for the actual cause) -- kept because it's
    // harmless and matches the reference, not because it's known to matter.
    Wire.setClock(400000);

    _imu.settings.gyroEnabled = 1;
    _imu.settings.gyroRange = _profile->gyroRangeDps;
    _imu.settings.gyroSampleRate = _profile->odrHz;
    _imu.settings.accelEnabled = 1;
    _imu.settings.accelRange = _profile->accelRangeG;
    _imu.settings.accelSampleRate = _profile->odrHz;
    _imu.settings.accelBandWidth = _profile->accelBandwidthHz;
    _imu.settings.tempEnabled = 0;

    if (_imu.begin() != 0) return false;

    _periodUs = 1000000UL / _profile->odrHz;
    _nextSampleUs = micros() + _periodUs;
    _lastSampleUs = 0;
    _logCounter = 0;
#if IMU_SERIAL_LOG
    Serial.println("t_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps");
#endif
#if DEBUG_SERIAL
    _heartbeatAtMs = millis() + IMU_HEARTBEAT_MS;
    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
#endif
    _detector.begin();
    return true;
  }

  const ImuProfile& profile() const { return *_profile; }

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

#if IMU_SERIAL_LOG
    if (++_logCounter >= IMU_SERIAL_LOG_EVERY_N) {
      _logCounter = 0;
      Serial.print((uint32_t)(d.timeUs / 1000));
      Serial.print(',');
      Serial.print(d.ax, 3);
      Serial.print(',');
      Serial.print(d.ay, 3);
      Serial.print(',');
      Serial.print(d.az, 3);
      Serial.print(',');
      Serial.print(d.gx, 1);
      Serial.print(',');
      Serial.print(d.gy, 1);
      Serial.print(',');
      Serial.println(d.gz, 1);
    }
#endif

    _detector.onSample(d);
    return _detector.nextTransition(out);
  }

 private:
  JumpDetector& _detector;
  LSM6DS3 _imu;
  const ImuProfile* _profile = &PROFILE_416HZ_8G;
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
                  _profile->odrHz + " Hz)";
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
    d.dt = _lastSampleUs ? (float)(t - _lastSampleUs) * 1e-6f : 1.0f / _profile->odrHz;
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
