// ============================================================================
// AzPipelineJumpDetector -- causal/online port of the az-only pipeline described in
// docs/reference/batch3/opentof-az-verarbeitungspipeline-zur-sprungerkennung.md, following
// that document's own "Implementierungshinweise für den MGM240S". Algorithm interface v1.
//   - filtfilt -> a one-sided 4th-order Butterworth (5 Hz), forward only.
//   - find_peaks (whole contact block) -> "track the last sample where az, after a
//     minimum, again exceeds a threshold" -- a causal proxy for the 2nd maximum.
//   - median(7), trailing; the fixed +33 ms landing correction carries over.
//
// Port of online_detect() in src/opentof_research/detectors/az_pipeline.py -- read
// that module docstring first. Batch 3: 84/98 real jumps matched, 76 ms mean timing
// error -- the weakest of the real-time options; kept as a documented comparison
// baseline. **Prefer BedCycleJumpDetector.h (or StaLtaJumpDetector.h).**
//
// Interface v1 usage: FINAL events only, no confidence/reasons/fields. The landing
// is reported when a candidate is confirmed (backdated to the candidate + 33 ms), the
// takeoff once the contact is confirmed over (backdated to the 2nd-max candidate,
// typically ~100 ms later -- within the 200 ms deadline). Events the firmware would
// drop are never sent (landing only after a reported takeoff and vice versa).
//
// Sample rate: v1 had the Butterworth coefficients hard-coded for 833 Hz, but the MCU
// delivers ~285 samples/s -- that silently moved the 5 Hz cutoff to ~1.7 Hz. v2
// designs the filter at runtime from the measured sample interval (two biquads,
// Butterworth Q = 0.5412 / 1.3066, bilinear with prewarping == scipy butter(4, 5 Hz)).
// All other durations are in seconds; only the median window is in samples.
// ============================================================================
#pragma once

#include <math.h>
#include <stdint.h>

#include "../core/JumpDetector.h"

class AzPipelineJumpDetector : public JumpDetector {
 public:
  const char* name() const override { return "AzPipeline v2"; }

  // Landings peak near 16 g; the filter adapts to the delivered sample rate.
  const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  void begin() override {
    for (int i = 0; i < 7; i++) _medianBuf[i] = 0.0f;
    _medianCount = 0;
    _medianHead = 0;
    for (int s = 0; s < 2; s++) { _z1[s] = 0.0f; _z2[s] = 0.0f; }
    _nSamples = 0;
    _dtSum = 0.0;
    _designed = false;

    _gravitySum = 0.0;
    _gravityCount = 0;
    _gravityZ = 0.0f;
    _gravityReady = false;
    _calibSeconds = 0.0f;

    _inContact = false;
    _haveLandingCandidate = false;
    _landingCandidateUs = 0;
    _quietSinceS = 0.0f;
    _secondsSinceLastEvent = 1e9f;
    _haveTakeoffCandidate = false;
    _takeoffCandidateUs = 0;
    _contactStartS = 0.0f;
    _tSeconds = 0.0f;
    _prevAbovePeak = false;
    _inAirReported = false;
  }

  void onSample(const ImuData& s) override {
    // ---- 0) design the Butterworth from the measured sample interval ----
    if (_nSamples > 0) _dtSum += (double)s.dt;
    _nSamples++;
    if (!_designed && _nSamples > kDesignSamples) designButterworth((float)(_dtSum / (double)(_nSamples - 1)));

    // ---- 1) median(7), trailing (causal) ----
    _medianBuf[_medianHead] = s.az;
    _medianHead = (_medianHead + 1) % 7;
    if (_medianCount < 7) _medianCount++;
    const float med = medianOfBuffer();

    // ---- 2) causal Butterworth (2 cascaded biquads, Direct Form II Transposed) ----
    const float filtered = _designed ? biquadCascade(med) : med;

    _tSeconds += s.dt;

    // ---- 3) one-time gravity calibration (first ~1.2 s) -- doubles as the filter's
    // warm-up: detection only starts once this is done. ----
    if (!_gravityReady) {
      _gravitySum += s.az;
      _gravityCount++;
      _calibSeconds += s.dt;
      if (_calibSeconds >= kGravityCalibS && _designed) {
        _gravityZ = (float)(_gravitySum / _gravityCount);
        _gravityReady = true;
      }
      return;
    }

    const float a = filtered - _gravityZ;
    _secondsSinceLastEvent += s.dt;

    if (!_inContact) {
      if (!_haveLandingCandidate) {
        if (fabsf(a) > kZeroThreshG && _secondsSinceLastEvent >= kMinFlightS) {
          _haveLandingCandidate = true;
          _landingCandidateUs = s.timeUs;
        }
      } else {
        if (fabsf(a) < kZeroThreshG) {
          _haveLandingCandidate = false;  // dipped back down without confirming -- noise, cancel
        } else if (fabsf(a) > kDetectThreshG) {
          // Confirmed contact: report the candidate's time (backdated) + 33 ms.
          if (_inAirReported) {
            landing(_landingCandidateUs + kLandingCorrectionUs, STAGE_FINAL);
            _inAirReported = false;
          }
          _inContact = true;
          _contactStartS = _tSeconds;
          _haveTakeoffCandidate = true;
          _takeoffCandidateUs = s.timeUs;
          _quietSinceS = 0.0f;
          _secondsSinceLastEvent = 0.0f;
          _haveLandingCandidate = false;
        }
      }
      _prevAbovePeak = a > kPeakHeightG;
    } else {
      const bool abovePeak = a > kPeakHeightG;
      // Bound candidate updates to shortly after landing (see the .py docstring).
      if (abovePeak && !_prevAbovePeak && (_tSeconds - _contactStartS) <= kMaxCandidateWindowS) {
        _haveTakeoffCandidate = true;
        _takeoffCandidateUs = s.timeUs;  // last rising-edge-after-a-dip wins, within the window
      }
      _prevAbovePeak = abovePeak;

      if (fabsf(a) < kZeroThreshG) {
        _quietSinceS += s.dt;
        if (_quietSinceS >= kConfirmS) {
          if (_haveTakeoffCandidate && !_inAirReported) {
            takeoff(_takeoffCandidateUs, STAGE_FINAL);
            _inAirReported = true;
          }
          _inContact = false;
          _secondsSinceLastEvent = 0.0f;
          _haveTakeoffCandidate = false;
        }
      } else {
        _quietSinceS = 0.0f;
      }
    }
  }

 private:
  float medianOfBuffer() {
    float tmp[7];
    for (int i = 0; i < _medianCount; i++) tmp[i] = _medianBuf[i];
    for (int i = 1; i < _medianCount; i++) {   // insertion sort, <= 7 elements
      float key = tmp[i];
      int j = i - 1;
      while (j >= 0 && tmp[j] > key) { tmp[j + 1] = tmp[j]; j--; }
      tmp[j + 1] = key;
    }
    return tmp[_medianCount / 2];
  }

  // 4th-order Butterworth low-pass = 2 biquads with Q = 1/(2cos(pi/8)), 1/(2cos(3pi/8)),
  // bilinear transform with prewarping at the cutoff (== scipy butter(4, fc)).
  void designButterworth(float dtAvg) {
    const float fs = 1.0f / dtAvg;
    const float k = tanf(3.14159265358979f * kCutoffHz / fs);
    const float k2 = k * k;
    static const float q[2] = {0.54119610f, 1.30656296f};
    for (int s = 0; s < 2; s++) {
      const float norm = 1.0f / (1.0f + k / q[s] + k2);
      _b0[s] = k2 * norm;
      _b1[s] = 2.0f * _b0[s];
      _b2[s] = _b0[s];
      _a1[s] = 2.0f * (k2 - 1.0f) * norm;
      _a2[s] = (1.0f - k / q[s] + k2) * norm;
      _z1[s] = _z2[s] = 0.0f;
    }
    _designed = true;
  }

  float biquadCascade(float x) {
    float in = x;
    for (int s = 0; s < 2; s++) {
      const float y = _b0[s] * in + _z1[s];
      _z1[s] = _b1[s] * in - _a1[s] * y + _z2[s];
      _z2[s] = _b2[s] * in - _a2[s] * y;
      in = y;
    }
    return in;
  }

  // ---- constants (batch-3 reference values; see README) ----
  static constexpr float kCutoffHz = 5.0f;
  static constexpr int kDesignSamples = 32;
  static constexpr float kGravityCalibS = 500.0f / 416.0f;  // ~1.2 s -- same window as the offline pipeline
  static constexpr float kDetectThreshG = 0.3f;
  static constexpr float kZeroThreshG = 0.05f;
  static constexpr float kPeakHeightG = 0.15f;
  static constexpr float kConfirmS = 30.0f / 416.0f;        // sustained quiet to confirm contact truly ended
  static constexpr float kMaxCandidateWindowS = 0.5f;       // 2nd-max candidates only accepted this soon after landing
  static constexpr float kMinFlightS = 0.3f;
  static constexpr uint64_t kLandingCorrectionUs = 33000;

  // ---- state ----
  float _medianBuf[7];
  int _medianCount = 0;
  int _medianHead = 0;
  float _b0[2], _b1[2], _b2[2], _a1[2], _a2[2];
  float _z1[2], _z2[2];
  int _nSamples = 0;
  double _dtSum = 0.0;
  bool _designed = false;

  double _gravitySum = 0.0;
  uint32_t _gravityCount = 0;
  float _gravityZ = 0.0f;
  bool _gravityReady = false;
  float _calibSeconds = 0.0f;

  bool _inContact = false;
  bool _haveLandingCandidate = false;
  uint64_t _landingCandidateUs = 0;
  float _quietSinceS = 0.0f;
  float _secondsSinceLastEvent = 1e9f;
  bool _haveTakeoffCandidate = false;
  uint64_t _takeoffCandidateUs = 0;
  float _contactStartS = 0.0f;
  float _tSeconds = 0.0f;
  bool _prevAbovePeak = false;
  bool _inAirReported = false;   // mirror of the firmware's jump state
};
