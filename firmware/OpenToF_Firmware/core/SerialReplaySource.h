// Reads raw 12-byte IMU FIFO samples from Serial and feeds them to the detector.
#pragma once

#include <Arduino.h>

#include "ImuSampleSource.h"

class SerialReplaySource : public ImuSampleSource {
 public:
  explicit SerialReplaySource(JumpDetector& detector)
      : ImuSampleSource(detector) {}

  bool begin() {
    resetSampleClock();
    _state = State::idle;
    _resumeAtMs = 0;
    _lastSampleMs = 0;
    beginSamples();
    return true;
  }

  bool poll(Transition& out) override {
    if (nextTransition(out)) return true;
    heartbeat("Serial replay", "bytes waiting = ", Serial.available());

    while (Serial.available() >= static_cast<int>(sizeof(RawImuSample))) {
      RawImuSample sample;
      uint8_t* sampleBytes = reinterpret_cast<uint8_t*>(&sample);
      for (size_t i = 0; i < sizeof(sample); i++) {
        sampleBytes[i] = static_cast<uint8_t>(Serial.read());
      }

      processSample(sample, nextSampleTimeUs(), samplePeriodSeconds());
      if (nextTransition(out)) return true;
    }

    return false;
  }

 protected:
  void onSampleReceived(uint32_t now) override {
    checkForGap(now);
    if (_state == State::idle) {
      _state = State::warmup;
      _resumeAtMs = now;
    }
    _lastSampleMs = now;
  }

  bool shouldMeasureSampleRate(uint32_t now) override {
    if (checkForGap(now)) return false;

    if (_state == State::warmup) {
      if (static_cast<uint32_t>(now - _resumeAtMs) >= 1000UL) {
        _state = State::tracking;
      }
      return false;
    }
    return _state == State::tracking;
  }

 private:
  enum class State { idle, warmup, tracking };

  State _state = State::idle;
  uint32_t _resumeAtMs = 0;
  uint32_t _lastSampleMs = 0;

  bool checkForGap(uint32_t now) {
    if (_state == State::idle ||
        static_cast<uint32_t>(now - _lastSampleMs) < IMU_HEARTBEAT_MS) {
      return false;
    }

    unlockSampleRate();
    resetRateAccumulation();
    _state = State::idle;
    return true;
  }
};
