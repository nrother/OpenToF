// Shared sample conversion, detector and heartbeat plumbing for IMU data sources.
#pragma once

#include <Arduino.h>

#include "../config/FirmwareConfig.h"
#include "ImuTypes.h"
#include "JumpDetector.h"
#include "Logging.h"
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

  explicit ImuSampleSource(JumpDetector& detector) : _detector(detector) {}

  void beginSamples() {
    _heartbeatAtMs = millis() + IMU_HEARTBEAT_MS;
    _heartbeatStartMs = millis();
    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
    _detector.begin();
  }

  bool nextTransition(Transition& out) { return _detector.nextTransition(out); }

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
  }

  void noteReadFailure() { _i2cFailuresSinceHeartbeat++; }

  void heartbeat(const char* source, const char* statusLabel = nullptr, uint32_t statusValue = 0) {
#if DEBUG_SERIAL
    const uint32_t now = millis();
    if ((int32_t)(now - _heartbeatAtMs) < 0) return;

    const uint32_t elapsedMs = now - _heartbeatStartMs;
    const uint32_t rateHz = elapsedMs == 0 ? 0 : _samplesSinceHeartbeat * 1000UL / elapsedMs;
    String line = String(source) + ": " + _samplesSinceHeartbeat + " samples in " +
                  (elapsedMs / 1000.0f) + " s (~" + rateHz + " Hz)";
    if (statusLabel != nullptr) {
      line += String(", ") + statusLabel + statusValue;
    }
    if (_i2cFailuresSinceHeartbeat > 0) {
      line += String(", ") + _i2cFailuresSinceHeartbeat + " I2C read failures";
    }
    LOG(line);

    _heartbeatAtMs = now + IMU_HEARTBEAT_MS;
    _heartbeatStartMs = now;
    _samplesSinceHeartbeat = 0;
    _i2cFailuresSinceHeartbeat = 0;
#else
    (void)source;
    (void)statusLabel;
    (void)statusValue;
#endif
  }

 private:
  JumpDetector& _detector;
  uint32_t _heartbeatAtMs = 0;
  uint32_t _heartbeatStartMs = 0;
  uint32_t _samplesSinceHeartbeat = 0;
  uint32_t _i2cFailuresSinceHeartbeat = 0;
};
