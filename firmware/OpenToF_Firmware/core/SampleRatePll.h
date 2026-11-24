// Tracks the sample clock from observed samples per elapsed time.
#pragma once

#include <stdint.h>

#include "../config/FirmwareConfig.h"

class SampleRatePll {
 public:
  explicit SampleRatePll(float initialRateHz) : _rateHz(initialRateHz) {}

  float rateHz() const { return _rateHz; }
  bool locked() const { return _locked; }
  void unlock() { _locked = false; }

  void update(uint32_t sampleCount, uint64_t elapsedUs) {
    if (sampleCount == 0 || elapsedUs == 0) return;

    const float measuredRateHz =
        static_cast<float>(sampleCount) * 1000000.0f / elapsedUs;
    if (!_locked) {
      _rateHz = measuredRateHz;
      _locked = true;
      return;
    }

    const float error = measuredRateHz - _rateHz;
    const float filterTimeUs = IMU_RATE_FILTER_TIME_CONSTANT_MS * 1000.0f;
    const float filteredAdjustment = error * elapsedUs / (filterTimeUs + elapsedUs);
    const float maxAdjustment =
        IMU_RATE_MAX_DRIFT_HZ_PER_MINUTE * elapsedUs / 60000000.0f;
    _rateHz += constrain(filteredAdjustment, -maxAdjustment, maxAdjustment);
  }

 private:
  float _rateHz;
  bool _locked = false;
};
