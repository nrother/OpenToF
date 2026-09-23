// ============================================================================
// AzPipelineJumpDetector -- causal/online port of the az-only pipeline described in
// tmp/third_data/opentof-az-verarbeitungspipeline-zur-sprungerkennung.md, following
// that document's own "Implementierungshinweise für den MGM240S":
//   - filtfilt -> a one-sided IIR Butterworth, same coefficients, forward only.
//   - find_peaks (whole contact block) -> "track the last sample where az, after a
//     minimum, again exceeds a threshold" -- a causal proxy for the 2nd maximum.
//   - median(7) is kept (trailing instead of centered) rather than swapped for the
//     document's EMA alternative -- a 7-tap running median is cheap enough on this
//     MCU that the extra robustness against single-sample I2C spikes isn't worth
//     giving up.
//   - the fixed +33ms landing correction carries over unchanged.
//
// This is a *direct* port of analysis/third_data/az_pipeline_online.py -- read that
// file's module docstring first. Validated there against tmp/third_data/take2.csv
// and take4.csv: 84/98 real jumps matched, landing MAE ~30-55ms, takeoff MAE
// ~95-125ms (takeoff visibly weaker than landing -- consistent with *every other*
// detector built in this project; see that docstring for why).
//
// IMPORTANT: analysis/third_data/compare_algorithms.py measures this design as the
// weakest of the three real-time-relevant options on the reference recordings --
// 84/98 matched, 76ms mean timing error, vs. StaLtaJumpDetector.h's 96/98 matched,
// 54ms. It exists because it was explicitly asked for (a faithful implementation of
// the source document's own online design, to compare against), not because it's
// the recommended choice -- **prefer StaLtaJumpDetector.h for production use.**
// This file is kept as a documented, working alternative and a real example of what
// "port the offline algorithm's own suggested online simplification" costs in
// practice versus a self-normalizing from-scratch design.
// ============================================================================
#pragma once

#include <math.h>
#include <stdint.h>

#include "../core/JumpDetector.h"

class AzPipelineJumpDetector : public JumpDetector {
 public:
  const char* name() const override { return "AzPipelineJumpDetector v1"; }

  // The reference recordings peaked near 16g -- same reasoning as
  // StaLtaJumpDetector.h. The Butterworth coefficients below are derived for this
  // exact rate (see kSos); if you change the profile, regenerate them (see the
  // comment above kSos for how).
  const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  void begin() override {
    for (int i = 0; i < 7; i++) _medianBuf[i] = 0.0f;
    _medianCount = 0;
    _medianHead = 0;
    for (int s = 0; s < 2; s++) { _z1[s] = 0.0f; _z2[s] = 0.0f; }

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
  }

  void onSample(const ImuData& s) override {
    // ---- 1) median(7), trailing (causal) ----
    _medianBuf[_medianHead] = s.az;
    _medianHead = (_medianHead + 1) % 7;
    if (_medianCount < 7) _medianCount++;
    const float med = medianOfBuffer();

    // ---- 2) causal Butterworth (forward-only, 2 cascaded biquads, Direct Form II
    // Transposed -- 2 state floats per section, matches scipy's SOS convention) ----
    const float filtered = biquadCascade(med);

    _tSeconds += s.dt;

    // ---- 3) one-time gravity calibration (first ~1.2s, same window the offline
    // pipeline uses) -- also doubles as the filter's warm-up period: detection only
    // starts once this is done, so the Butterworth's zero-initial-state transient
    // (which otherwise produces a spurious first "landing") has already settled. ----
    if (!_gravityReady) {
      _gravitySum += s.az;
      _gravityCount++;
      _calibSeconds += s.dt;
      if (_calibSeconds >= kGravityCalibS) {
        _gravityZ = (float)(_gravitySum / _gravityCount);
        _gravityReady = true;
      }
      return;
    }

    const float a = filtered - _gravityZ;
    _secondsSinceLastEvent += s.dt;

    if (!_inContact) {
      if (!_haveLandingCandidate) {
        // watch for the first rise through the zero threshold out of quiet
        if (fabsf(a) > kZeroThreshG && _secondsSinceLastEvent >= kMinFlightS) {
          _haveLandingCandidate = true;
          _landingCandidateUs = s.timeUs;
        }
      } else {
        if (fabsf(a) < kZeroThreshG) {
          _haveLandingCandidate = false;  // dipped back down without confirming -- noise, cancel
        } else if (fabsf(a) > kDetectThreshG) {
          // Confirmed: a real contact. Report the *candidate's* time (backdated),
          // +33ms fixed correction -- same as the offline pipeline's landing_correction.
          landing(_landingCandidateUs + kLandingCorrectionUs);
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
      // Bound candidate updates to shortly after landing: the physical model
      // (a=0 -> 1st max -> trough -> 2nd max -> takeoff) completes quickly (real
      // contacts run ~0.35-0.5s). Without this bound, a noisy ringdown keeps
      // re-triggering "the last rising edge" far past the true 2nd maximum -- traced
      // against real data before this bound was added (see the .py docstring).
      if (abovePeak && !_prevAbovePeak && (_tSeconds - _contactStartS) <= kMaxCandidateWindowS) {
        _haveTakeoffCandidate = true;
        _takeoffCandidateUs = s.timeUs;  // last rising-edge-after-a-dip wins, within the window
      }
      _prevAbovePeak = abovePeak;

      if (fabsf(a) < kZeroThreshG) {
        _quietSinceS += s.dt;
        if (_quietSinceS >= kConfirmS) {
          if (_haveTakeoffCandidate) {
            takeoff(_takeoffCandidateUs);
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
  // ---- causal median(7): trailing window, small buffer, insertion-sort-on-copy ----
  float medianOfBuffer() {
    float tmp[7];
    for (int i = 0; i < _medianCount; i++) tmp[i] = _medianBuf[i];
    // insertion sort -- 7 elements at most, trivially cheap
    for (int i = 1; i < _medianCount; i++) {
      float key = tmp[i];
      int j = i - 1;
      while (j >= 0 && tmp[j] > key) { tmp[j + 1] = tmp[j]; j--; }
      tmp[j + 1] = key;
    }
    return tmp[_medianCount / 2];
  }

  // ---- causal 4th-order Butterworth, 5 Hz cutoff, as 2 cascaded biquads ----
  // Coefficients generated with:
  //   scipy.signal.butter(4, 5.0 / (833.0 / 2), btype="low", output="sos")
  // (833 Hz = PROFILE_833HZ_16G's rate; regenerate for a different profile/cutoff.)
  // Direct Form II Transposed per section: y = b0*x + z1; z1' = b1*x - a1*y + z2;
  // z2' = b2*x - a2*y. Each section's a0 is already normalized to 1 (scipy's SOS
  // convention), matching this implementation.
  static constexpr float kSosB0[2] = {1.2042139608e-07f, 1.0f};
  static constexpr float kSosB1[2] = {2.4084279216e-07f, 2.0f};
  static constexpr float kSosB2[2] = {1.2042139608e-07f, 1.0f};
  static constexpr float kSosA1[2] = {-1.9313007236f, -1.9701501617f};
  static constexpr float kSosA2[2] = {0.93267504116f, 0.97155212463f};

  float biquadCascade(float x) {
    float in = x;
    for (int s = 0; s < 2; s++) {
      const float y = kSosB0[s] * in + _z1[s];
      _z1[s] = kSosB1[s] * in - kSosA1[s] * y + _z2[s];
      _z2[s] = kSosB2[s] * in - kSosA2[s] * y;
      in = y;
    }
    return in;
  }

  // ---- tuned constants (grid-searched jointly on take2+take4 -- see README) ----
  static constexpr float kGravityCalibS = 500.0f / 416.0f;  // ~1.2s -- same window as the offline pipeline
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
  float _z1[2], _z2[2];  // biquad states

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
};
