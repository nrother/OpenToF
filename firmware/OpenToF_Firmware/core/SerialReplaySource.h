// Reads raw 12-byte IMU FIFO samples from Serial and feeds them to the detector.
#pragma once

#include <Arduino.h>

#include "ImuSampleSource.h"
#include "Micros64.h"

class SerialReplaySource : public ImuSampleSource {
 public:
  explicit SerialReplaySource(JumpDetector& detector) : ImuSampleSource(detector) {}

  bool begin() {
    _lastReceivedUs = 0;
    _sampleTimeUs = 0;
    _hasReceivedSample = false;
    beginSamples();
    return true;
  }

  bool poll(Transition& out) override {
    if (nextTransition(out)) return true;
#if DEBUG_SERIAL
    heartbeat("Serial replay", "bytes waiting = ", Serial.available());
#endif

    while (Serial.available() >= static_cast<int>(sizeof(RawImuSample))) {
      RawImuSample sample;
      uint8_t* sampleBytes = reinterpret_cast<uint8_t*>(&sample);
      for (size_t i = 0; i < sizeof(sample); i++) {
        sampleBytes[i] = static_cast<uint8_t>(Serial.read());
      }

      processSampleAtArrival(sample);
      if (nextTransition(out)) return true;
    }

    return false;
  }

 private:
  uint64_t _lastReceivedUs = 0;
  uint64_t _sampleTimeUs = 0;
  bool _hasReceivedSample = false;

  void processSampleAtArrival(const RawImuSample& sample) {
    const uint64_t receivedUs = micros64();
    const uint64_t elapsedUs =
        _hasReceivedSample ? receivedUs - _lastReceivedUs : 0;
    _lastReceivedUs = receivedUs;
    _hasReceivedSample = true;
    _sampleTimeUs += elapsedUs;
    processSample(sample, _sampleTimeUs, elapsedUs / 1000000.0f);
  }
};
