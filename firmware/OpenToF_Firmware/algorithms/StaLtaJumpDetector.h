// ============================================================================
// StaLtaJumpDetector -- causal STA/LTA (short-term/long-term energy ratio) jump
// detector, fusing accelerometer + gyroscope.
//
// This is a direct port of analysis/third_data/analyze_third_batch.py's
// stalta_detect(), grid-searched jointly against tmp/third_data/take2.csv and
// take4.csv: 96/98 real jumps matched (98%), F1 ~= 0.95, ~35-90 ms timing MAE. See
// analysis/third_data/README.md for the full write-up, including why a
// fixed-threshold envelope (tried first) was rejected -- it worked well on one
// reference recording and badly on the other under the same thresholds, because a
// single absolute threshold doesn't generalize across sessions with different
// overall activity levels. STA/LTA fixes that by thresholding a *ratio* that keeps
// renormalizing to the recording's own recent energy level instead.
//
// Algorithm, in one line: track a fast (~50 ms, "STA") and a slow (~1 s, "LTA")
// average of the signal's energy for both accel (deviation-from-gravity squared) and
// gyro (magnitude squared); their ratio spikes the instant a footfall starts and
// collapses once it's over. Landing fires when the ratio rises through
// kEnterThresh, takeoff when it falls back through kExitThresh (two independent
// hysteresis thresholds, same idea as the worked example in MyJumpDetector.h, just
// on a self-normalizing statistic instead of the raw envelope) -- a refractory
// debounce (kMinContactS / kMinFlightS) then suppresses any remaining chatter from a
// contact's ringdown right at the threshold.
//
// Both STA and LTA are single exponentially-weighted moving averages: O(1) state (4
// floats), O(1) work per sample (~4 mult-adds, 2 divisions, no sqrt beyond what
// accelMagnitude()/gyroMagnitude() already compute, no stored history/ring buffer at
// all). The ~1 s LTA window is the *only* "memory" the detector has of the past --
// exactly the "use the most recent 1-2 seconds, don't wait for the whole recording"
// requirement this was built for, expressed directly in the algorithm rather than as
// a buffer bolted on afterward.
//
// Fusing the gyro (not just accel, unlike the offline notes this batch shipped
// with -- see analysis/third_data/README.md's "Does the gyroscope actually help?")
// gave a measured ~27% reduction in false positives and a small timing-precision
// improvement on the reference recordings, at equal recall: gyro decays back to its
// quiet baseline faster and cleaner than accel after each contact, which sharpens
// exactly the edge (contact truly over) that a bed's post-impact ringdown otherwise
// blurs in accel alone.
// ============================================================================
#pragma once

#include <math.h>
#include <stdint.h>

#include "../core/JumpDetector.h"

class StaLtaJumpDetector : public JumpDetector {
 public:
  // Bump this string whenever the tuning below changes -- it's what shows up over
  // BLE, so it's the only way to tell from the app which version is flashed.
  const char* name() const override { return "StaLtaJumpDetector v1"; }

  // The reference recordings (take2/take4) peaked near 16g on impact, so force the
  // 16g-range profile explicitly rather than relying on IMU_USE_HIGH_RATE_PROFILE's
  // default (FirmwareConfig.h) -- a real landing clipping at 8g would be silently
  // wrong, not just noisy. 833Hz over 416Hz costs nothing here: every time constant
  // below is in seconds (via s.dt), so the detector is sample-rate-independent.
  const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  void begin() override {
    _onBed = false;
    _initialized = false;
    _staA = _ltaA = _staG = _ltaG = 0.0f;
    _secondsSinceLastEvent = 0.0f;
    _haveLastEvent = false;
  }

  void onSample(const ImuData& s) override {
    // ---- 1) per-channel instantaneous energy ----
    const float devA = s.accelMagnitude() - kGravityG;
    const float energyA = devA * devA;
    const float magG = s.gyroMagnitude();
    const float energyG = magG * magG;

    if (!_initialized) {
      // Seed both averages from the first sample so the ratio starts at a neutral
      // ~1.0 instead of a 0/0 or a spurious startup spike.
      _staA = _ltaA = energyA;
      _staG = _ltaG = energyG;
      _initialized = true;
      return;
    }

    // ---- 2) update the four EWMAs ----
    // alpha = 1 - exp(-dt/tau), linearized to dt/tau: valid because dt (~1.2-2.4 ms
    // at 416-833 Hz) is always much smaller than tau (50 ms / 1 s) here, and it
    // avoids a transcendental call on every sample of every channel. Clamped to 1 in
    // case a stall ever produces an unusually large dt.
    const float dt = s.dt;
    const float alphaStaA = fminf(dt / kStaTauS, 1.0f);
    const float alphaLtaA = fminf(dt / kLtaTauS, 1.0f);
    const float alphaStaG = fminf(dt / kStaGyroTauS, 1.0f);
    const float alphaLtaG = fminf(dt / kLtaGyroTauS, 1.0f);

    _staA += alphaStaA * (energyA - _staA);
    _ltaA += alphaLtaA * (energyA - _ltaA);
    _staG += alphaStaG * (energyG - _staG);
    _ltaG += alphaLtaG * (energyG - _ltaG);

    const float ratioA = _staA / (_ltaA + kEps);
    const float ratioG = _staG / (_ltaG + kEps);
    const float score = 0.5f * (ratioA + ratioG);  // "avg" fusion -- see README

    // ---- 3) hysteresis + refractory debounce, then report ----
    // Elapsed time is tracked as an accumulated float (sum of s.dt), not a
    // difference of s.timeUs, so this doesn't need to assume a timestamp width/type
    // or handle wraparound -- it only ever uses the fields onSample() is documented
    // to receive.
    _secondsSinceLastEvent += dt;

    if (!_onBed && score > kEnterThresh) {
      if (!_haveLastEvent || _secondsSinceLastEvent >= kMinFlightS) {
        _onBed = true;
        _secondsSinceLastEvent = 0.0f;
        _haveLastEvent = true;
        landing(s.timeUs);  // vibration/rotation energy spiked: gymnast hit the bed
      }
    } else if (_onBed && score < kExitThresh) {
      if (_secondsSinceLastEvent >= kMinContactS) {
        _onBed = false;
        _secondsSinceLastEvent = 0.0f;
        takeoff(s.timeUs);  // energy collapsed back to baseline: gymnast left the bed
      }
    }
  }

 private:
  // ---- tuned constants (grid-searched jointly on take2+take4 -- see README) ----
  static constexpr float kGravityG = 1.0f;       // this IMU reports accel directly in g
  static constexpr float kStaTauS = 0.05f;
  static constexpr float kLtaTauS = 1.0f;
  static constexpr float kStaGyroTauS = 0.05f;
  static constexpr float kLtaGyroTauS = 1.0f;
  static constexpr float kEnterThresh = 2.5f;    // ratio rising through this -> landing
  static constexpr float kExitThresh = 1.0f;     // ratio falling through this -> takeoff
  static constexpr float kMinContactS = 0.2f;    // a real contact is never shorter than this
  static constexpr float kMinFlightS = 0.3f;     // a real flight is never shorter than this
  static constexpr float kEps = 1e-6f;

  // ---- state ----
  bool _onBed = false;
  bool _initialized = false;
  bool _haveLastEvent = false;
  float _staA = 0.0f, _ltaA = 0.0f, _staG = 0.0f, _ltaG = 0.0f;
  float _secondsSinceLastEvent = 0.0f;
};
