// ============================================================================
// StaLtaJumpDetector -- causal STA/LTA (short-term/long-term energy ratio) jump
// detector, fusing accelerometer + gyroscope. Algorithm interface v1.
//
// Port of src/opentof_research/detectors/stalta.py (batch-3 parameters, see
// experiments/batch3_mg24/stalta.py and README.md): 96/98 real jumps matched on
// batch 3; flight-time MAE 28 ms under the frozen-sync protocol (the newer
// BedCycleJumpDetector.h reaches 11 ms on the same data).
//
// Algorithm, in one line: track a fast (~50 ms, "STA") and a slow (~1 s, "LTA")
// average of the signal's energy for both accel (deviation-from-gravity squared) and
// gyro (magnitude squared); their ratio spikes the instant a footfall starts and
// collapses once it's over. Landing fires when the averaged ratio rises through
// kEnterThresh, takeoff when it falls back through kExitThresh; a refractory
// debounce (kMinContactS / kMinFlightS) suppresses ringdown chatter.
//
// Interface v1 usage: every event is reported once, as FINAL, at the sample where
// the threshold is crossed (no provisional stage: there is nothing to refine), with
// no confidence, reasons or custom fields. Events the firmware would drop are never
// sent: landings only after a reported takeoff, takeoffs only while on the bed.
//
// Sample rate: every time constant is in seconds via s.dt (alpha = dt/tau,
// linearized; dt << tau at 285-833 samples/s), so the real ~285 samples/s with
// jitter is fine.
// ============================================================================
#pragma once

#include <math.h>
#include <stdint.h>

#include "../core/JumpDetector.h"

class StaLtaJumpDetector : public JumpDetector {
 public:
  const char* name() const override { return "StaLta v2"; }

  // Landings peak near 16 g; an 8 g range would clip them.
  const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  void begin() override {
    _onBed = false;
    _initialized = false;
    _staA = _ltaA = _staG = _ltaG = 0.0f;
    _secondsSinceLastEvent = 0.0f;
    _haveLastEvent = false;
    _inAirReported = false;
  }

  void onSample(const ImuData& s) override {
    // ---- 1) per-channel instantaneous energy ----
    const float devA = s.accelMagnitude() - kGravityG;
    const float energyA = devA * devA;
    const float magG = s.gyroMagnitude();
    const float energyG = magG * magG;

    if (!_initialized) {
      // Seed both averages from the first sample so the ratio starts at ~1.0.
      _staA = _ltaA = energyA;
      _staG = _ltaG = energyG;
      _initialized = true;
      return;
    }

    // ---- 2) update the four EWMAs (alpha = dt/tau, clamped for stalls) ----
    const float dt = s.dt;
    _staA += fminf(dt / kStaTauS, 1.0f) * (energyA - _staA);
    _ltaA += fminf(dt / kLtaTauS, 1.0f) * (energyA - _ltaA);
    _staG += fminf(dt / kStaGyroTauS, 1.0f) * (energyG - _staG);
    _ltaG += fminf(dt / kLtaGyroTauS, 1.0f) * (energyG - _ltaG);

    const float score = 0.5f * (_staA / (_ltaA + kEps) + _staG / (_ltaG + kEps));  // "avg" fusion

    // ---- 3) hysteresis + refractory debounce, then report ----
    _secondsSinceLastEvent += dt;
    if (!_onBed && score > kEnterThresh) {
      if (!_haveLastEvent || _secondsSinceLastEvent >= kMinFlightS) {
        _onBed = true;
        _secondsSinceLastEvent = 0.0f;
        _haveLastEvent = true;
        if (_inAirReported) {                 // a landing needs a reported takeoff
          landing(s.timeUs, STAGE_FINAL);
          _inAirReported = false;
        }
      }
    } else if (_onBed && score < kExitThresh) {
      if (_secondsSinceLastEvent >= kMinContactS) {
        _onBed = false;
        _secondsSinceLastEvent = 0.0f;
        if (!_inAirReported) {                // always true here; kept symmetric with landing
          takeoff(s.timeUs, STAGE_FINAL);
          _inAirReported = true;
        }
      }
    }
  }

 private:
  // ---- tuned constants (grid-searched jointly on batch-3 take2+take4) ----
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
  bool _inAirReported = false;   // mirror of the firmware's jump state: last reported event was a takeoff
  float _staA = 0.0f, _ltaA = 0.0f, _staG = 0.0f, _ltaG = 0.0f;
  float _secondsSinceLastEvent = 0.0f;
};
