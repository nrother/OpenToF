// Shared sample conversion, detector and heartbeat plumbing for IMU data sources.
#pragma once

#include <Arduino.h>

#include "../config/FirmwareConfig.h"
#include "ImuTypes.h"
#include "JumpDetector.h"
#include "Logging.h"
#include "Micros64.h"
#include "SampleRatePll.h"
#include "Transition.h"

class ImuSampleSource : public TransitionSource {
 public:
  const char* name() const override { return _detector.name(); }
  const char* fieldsJson() const override { return _detector.fieldsJson(); }
  const char* reasonsJson() const override { return _detector.reasonsJson(); }
  const char* confidenceKind() const override { return _detector.confidenceKind(); }

 protected:
  struct __attribute__((packed)) RawImuSample {
    int16_t gx;
    int16_t gy;
    int16_t gz;
    int16_t ax;
    int16_t ay;
    int16_t az;
  };

  static_assert(sizeof(RawImuSample) == 12, "Unexpected IMU sample size");

  explicit ImuSampleSource(JumpDetector& detector)
      : _detector(detector), _sampleRatePll(IMU_SAMPLE_RATE_HZ) {}

  void beginSamples() {
    const uint32_t now = millis();
    _heartbeatAtMs = now + IMU_HEARTBEAT_MS;
    _heartbeatStartMs = now;
    _rateHeartbeatStartUs = micros64();
    _samplesSinceHeartbeat = 0;
    resetRateAccumulation();
    _i2cFailuresSinceHeartbeat = 0;
    _detector.begin();
  }

  bool nextTransition(Transition& out) { return _detector.nextTransition(out); }

  float sampleRateHz() const { return _sampleRatePll.rateHz(); }

  float samplePeriodSeconds() const { return 1.0f / sampleRateHz(); }

  void unlockSampleRate() { _sampleRatePll.unlock(); }

  virtual void onSampleReceived(uint32_t now) { (void)now; }

  virtual bool shouldMeasureSampleRate(uint32_t now) {
    (void)now;
    return true;
  }

  void resetSampleClock() {
    _sampleTimeUs = 0;
    _sampleTimeFractionUs = 0.0f;
  }

  uint64_t nextSampleTimeUs() {
    _sampleTimeFractionUs += 1000000.0f / sampleRateHz();
    const uint64_t wholeMicroseconds =
        static_cast<uint64_t>(_sampleTimeFractionUs);
    _sampleTimeFractionUs -= wholeMicroseconds;
    _sampleTimeUs += wholeMicroseconds;
    return _sampleTimeUs;
  }

  void processSample(const RawImuSample& raw, uint64_t timeUs, float dt) {
    ImuData sample;
    sample.dt = dt;
    sample.timeUs = timeUs;

    const float gScale = 70.0f / 1000.0f;
    sample.gx = raw.gx * gScale;
    sample.gy = raw.gy * gScale;
    sample.gz = raw.gz * gScale;
    sample.ax = raw.ax / 2048.0f;
    sample.ay = raw.ay / 2048.0f;
    sample.az = raw.az / 2048.0f;

    _detector.onSample(sample);
    _samplesSinceHeartbeat++;
    onSampleReceived(millis());
  }

  void noteReadFailure() { _i2cFailuresSinceHeartbeat++; }

  void heartbeat(const char* source, const char* statusLabel = nullptr, uint32_t statusValue = 0) {
    const uint32_t now = millis();
    if ((int32_t)(now - _heartbeatAtMs) < 0) return;

    const uint32_t elapsedMs = now - _heartbeatStartMs;
    const uint64_t nowUs = micros64();
    const uint64_t elapsedUs = nowUs - _rateHeartbeatStartUs;
    const uint32_t samples = _samplesSinceHeartbeat;
    updateSampleRate(samples, elapsedUs, now);
#if DEBUG_SERIAL
    const uint32_t rateHz =
        elapsedUs == 0
            ? 0
            : (static_cast<uint64_t>(samples) * 1000000ULL + elapsedUs / 2) /
                  elapsedUs;
    String line = String(source) + ": " + _samplesSinceHeartbeat + " samples in " +
                  (elapsedMs / 1000.0f) + " s (~" + rateHz + " Hz), PLL = " +
                  String(sampleRateHz(), 2) + " Hz";
    if (!_sampleRatePll.locked()) line += " (acquiring)";
    if (statusLabel != nullptr) {
      line += String(", ") + statusLabel + statusValue;
    }
    if (_i2cFailuresSinceHeartbeat > 0) {
      line += String(", ") + _i2cFailuresSinceHeartbeat + " I2C read failures";
    }
    LOG(line);
#else
    (void)source;
    (void)statusLabel;
    (void)statusValue;
#endif
    _heartbeatAtMs = now + IMU_HEARTBEAT_MS;
    _heartbeatStartMs = now;
    _rateHeartbeatStartUs = nowUs;
    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
  }

 private:
  JumpDetector& _detector;
  SampleRatePll _sampleRatePll;
  uint32_t _heartbeatAtMs = 0;
  uint32_t _heartbeatStartMs = 0;
  uint64_t _rateHeartbeatStartUs = 0;
  uint32_t _samplesSinceHeartbeat = 0;
  uint32_t _i2cFailuresSinceHeartbeat = 0;
  uint32_t _rateSampleCount = 0;
  uint64_t _rateElapsedUs = 0;
  uint64_t _sampleTimeUs = 0;
  float _sampleTimeFractionUs = 0.0f;

 protected:
  void resetRateAccumulation() {
    _rateSampleCount = 0;
    _rateElapsedUs = 0;
  }

 private:
  void updateSampleRate(uint32_t samples, uint64_t elapsedUs, uint32_t now) {
    if (!shouldMeasureSampleRate(now)) {
      resetRateAccumulation();
      return;
    }

    if (samples == 0 || elapsedUs == 0) {
      resetRateAccumulation();
      return;
    }

    _rateSampleCount += samples;
    _rateElapsedUs += elapsedUs;
    if (_rateElapsedUs >= static_cast<uint64_t>(IMU_RATE_INTERVAL_MS) * 1000ULL) {
      _sampleRatePll.update(_rateSampleCount, _rateElapsedUs);
      resetRateAccumulation();
    }
  }
};
