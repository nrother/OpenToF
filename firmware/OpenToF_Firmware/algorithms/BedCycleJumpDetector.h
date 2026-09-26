// ============================================================================
// BedCycleJumpDetector -- causal "bed-cycle" jump detector (accel + gyro),
// algorithm interface v1 (provisional + final events, confidence, reasons,
// custom fields).
//
// Port of src/opentof_research/detectors/bed_cycle.py (BedCycleDetector), statement
// for statement; tests/test_firmware_host.py compiles this header on the host and
// checks it reproduces the Python reference event for event. Research write-up:
// experiments/batch4_mg24/ALGORITHM_RESEARCH.md.
//
// Idea: the IMU sits on the trampoline bed, and one bed contact has a fixed
// physical shape in the gravity-aligned ("vertical") acceleration a_v:
//   landing  -> very sharp onset of gyro/vibration energy (a_v dips to ~-4 g)
//   contact  -> positive push hump (+2..3 g)
//   takeoff  -> a_v crosses zero ~80 ms *before* takeoff and reaches a sharp
//               minimum just *after* it; then the bed rings freely at ~7.5 Hz.
// Takeoff comes from that *shape* (8 Hz low-passed a_v minimum: jitter vs. video
// ground truth std 13 ms), not from an energy drop.
//
// Events (all timestamps backdated to the physical event):
//   landing  PROVISIONAL at the gyro threshold crossing (~0-25 ms after touch-down)
//            FINAL       ~80 ms after touch-down, timed at the onset found in a
//                        60 ms ring buffer, carrying the landing intensity
//   takeoff  PROVISIONAL at the a_v zero crossing: a *prediction* ~80 ms ahead
//                        (timestamp in the future), carrying the push intensity
//            FINAL       ~100-150 ms after takeoff (<= 200 ms), timed at the a_v minimum
// Landings are only reported after a reported takeoff (never one the firmware would
// drop). No retractions: every provisional event is followed by its final.
//
// Batch-3 result (final events, leave-one-recording-out, frozen sync): F1 0.96,
// flight-time MAE 11 ms (p90 29 ms), landing MAE 7 ms, takeoff MAE 11 ms;
// STA/LTA on the same protocol: F1 0.92, flight MAE 28 ms. Not yet validated on
// batch 4. Confidence is heuristic (penalties per reason bit).
//
// Sample rate: the low-pass and ring buffer are designed at runtime from the
// measured sample interval, so the real ~285 samples/s (with jitter) of the 833 Hz
// profile works; every other constant is in seconds.
// Cost per sample: 1 biquad, 4 expf, ~40 float ops, 1 sqrtf; one <=160-entry scan
// of the ring buffer per landing.
// ============================================================================
#pragma once

#include <math.h>
#include <stdint.h>

#include "../core/JumpDetector.h"

class BedCycleJumpDetector : public JumpDetector {
 public:
  const char* name() const override { return "BedCycle v2"; }

  // Landings peak near 16 g; an 8 g range would clip the landing dip.
  const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  const char* confidenceKind() const override { return "heuristic"; }
  const char* reasonsJson() const override {
    return "[\"fast/final disagree\",\"timeout fallback\",\"weak push\",\"contact out of range\","
           "\"samples lost\",\"accel clipped\",\"warm-up\"]";
  }
  const char* fieldsJson() const override {
    return "[{\"id\":\"pi\",\"name\":\"Push-off intensity\",\"t\":\"u8\",\"on\":\"T\",\"rel\":true,\"na\":255,"
           "\"desc\":\"Strength of the push-off before this takeoff, 100 = typical for this session\"},"
           "{\"id\":\"li\",\"name\":\"Landing intensity\",\"t\":\"u8\",\"on\":\"L\",\"rel\":true,\"na\":255,"
           "\"desc\":\"How hard the landing hit the bed, 100 = typical for this session\"}]";
  }

  void begin() override {
    _t = 0.0;
    _nSamples = 0;
    _dtSum = 0.0;
    _dtRef = 0.0f;
    _designed = false;
    _z1 = _z2 = 0.0f;
    _haveG = false;
    _gx = _gy = _gz = 0.0f;
    _gyr = 0.0f;
    _env = 0.0f;
    _haveNoise = false;
    _noise = 0.0f;
    _haveContactLevel = false;
    _contactLevel = 0.0f;
    _haveHumpRef = _haveLandRef = false;
    _humpRef = _landRef = 0.0f;
    _bufLen = 2;
    _bufHead = _bufCount = 0;
    _inContact = false;
    _tState = -1e9;
    _tLastOut = -1e9;
    _awaitingTakeoff = true;
    _gapFlight = false;
    resetContact();
  }

  void onSample(const ImuData& s) override {
    const float dt = (_nSamples == 0) ? 0.0f : s.dt;   // first sample: nothing to integrate yet
    _t += (double)dt;
    const double t = _t;
    const bool warm = t >= (double)kWarmupS;

    // ---- design the low-pass (and ring buffer) from the measured sample interval ----
    if (_nSamples > 0) _dtSum += (double)dt;
    _nSamples++;
    if (!_designed && _nSamples > kDesignSamples) designFilter((float)(_dtSum / (double)(_nSamples - 1)));
    const bool gap = _designed && dt > kGapFactor * _dtRef;
    const bool clip = fabsf(s.ax) >= kClipG || fabsf(s.ay) >= kClipG || fabsf(s.az) >= kClipG;

    // ---- gravity-aligned vertical acceleration a_v (low-passed) ----
    if (!_haveG) { _gx = s.ax; _gy = s.ay; _gz = s.az; _haveG = true; }
    const float aG = 1.0f - expf(-dt / kGravityTauS);
    _gx += aG * (s.ax - _gx);
    _gy += aG * (s.ay - _gy);
    _gz += aG * (s.az - _gz);
    const float gNorm = sqrtf(_gx * _gx + _gy * _gy + _gz * _gz);
    const float aVraw = (s.ax * _gx + s.ay * _gy + s.az * _gz) / gNorm - gNorm;
    const float aV = _designed ? biquad(aVraw) : 0.0f;

    // ---- gyro level, decaying (ringing) envelope, onset ring buffer ----
    _gyr += (1.0f - expf(-dt / kGyroTauS)) * (s.gyroMagnitude() - _gyr);
    const float decayed = _env * expf(-dt / kRingTauS);
    _env = (_gyr > decayed) ? _gyr : decayed;
    const float envLag = (_bufCount > 0) ? at(0).env : _env;   // envelope ~60 ms ago
    push(t, _gyr, _env);

    if (!_inContact) {
      _gapFlight |= gap;
      // flight noise level: learned only once the takeoff ringing has settled
      if (!_haveNoise) { _noise = _gyr; _haveNoise = true; }
      else if (t - _tLastOut > 0.3) _noise += (1.0f - expf(-dt / kNoiseTauS)) * (_gyr - _noise);

      float thr = kKNoise * _noise;
      if (_haveContactLevel && kKContact * _contactLevel > thr) thr = kKContact * _contactLevel;
      if (warm && _designed && _gyr > thr && _gyr > kKRing * envLag && t - _tLastOut >= kMinFlightS) {
        const bool marginLow = _gyr < kLowMarginRatio * thr;
        const bool first = !_haveContactLevel;
        resetContact();
        _reportLanding = !_awaitingTakeoff;
        _landGap = _gapFlight;
        _landPenalty = marginLow ? kLowMarginPenalty : 0;
        const uint8_t reasons = (_landGap ? R_SAMPLES_LOST : 0) | (first ? R_WARMUP : 0);
        if (_reportLanding) {
          EventInfo info;
          info.confidence = conf(kConfProvisionalLanding, reasons, _landPenalty);
          info.reasons = reasons;
          info.addU8(kNa);
          landing(toUs(t - kLandingFastS, t, s.timeUs), STAGE_PROVISIONAL, info);
        }
        _awaitingTakeoff = true;
        _landReasons = reasons;
        _pendingOnset = true;
        _tPendingOnset = t;
        _landFinalDue = true;
        _tLandFinal = t + kLandPeakWinS;
        _inContact = true;
        _tState = t;
      }
    } else {
      if (_gyr > _contactGyroPeak) _contactGyroPeak = _gyr;
      _contactGap |= gap;
      _contactClip |= clip;

      // final landing: resolve the onset from the ring buffer, emit after the peak window
      if (_pendingOnset && t - _tPendingOnset >= 0.5 * kOnsetLookbackS) {
        const float onsetThr = kOnsetKNoise * _noise;
        double onset = _tPendingOnset;
        for (int i = 0; i < _bufCount; i++) {
          const Entry& e = at(i);
          if (e.t <= _tPendingOnset && e.gyr > onsetThr) { onset = e.t; break; }
        }
        _onset = onset;
        _haveOnset = true;
        _pendingOnset = false;
      }
      if (_landFinalDue) {
        if (_gyr > _landPeak) _landPeak = _gyr;
        _landGap |= gap;
        _landClip |= clip;
        if (t >= _tLandFinal && _haveOnset) {
          const uint8_t reasons = _landReasons | (_landGap ? R_SAMPLES_LOST : 0) | (_landClip ? R_CLIPPED : 0);
          if (_reportLanding) {
            EventInfo info;
            info.confidence = conf(kConfFinalLanding, reasons, _landPenalty);
            info.reasons = reasons;
            info.addU8(relU8(_landPeak, _haveLandRef, _landRef));
            landing(toUs(_onset + kLandingRefineS, t, s.timeUs), STAGE_FINAL, info);
          }
          if (!_haveLandRef) { _landRef = _landPeak; _haveLandRef = true; }
          else _landRef += kRefAlpha * (_landPeak - _landRef);
          _landFinalDue = false;
        }
      }

      const double inContactFor = t - _tState;
      if (inContactFor > 0.05 && aV > _humpPeak) _humpPeak = aV;
      if (_prevAv >= 0.0f && aV < 0.0f) { _haveZero = true; _tZero = t; }
      else if (aV >= 0.0f) _haveZero = false;

      const bool humpOk = _humpPeak >= kHumpMinG && inContactFor >= kMinTakeoffAfterS;
      if (humpOk && !_crossed && _haveZero && _tZero - _tState >= kMinTakeoffAfterS &&
          aV < -kCrossRel * _humpPeak) {
        _crossed = true;
        _tCross = t;
        _tFastOut = _tZero + kTakeoffFastS;
        const uint8_t reasons = takeoffReasons(_tFastOut);
        _awaitingTakeoff = false;
        EventInfo info;
        info.confidence = conf(kConfProvisionalTakeoff, reasons, 0);
        info.reasons = reasons;
        info.addU8(pushIntensity());
        takeoff(toUs(_tFastOut, t, s.timeUs), STAGE_PROVISIONAL, info);
        _vMin = aV;
        _tMin = t;
      }
      if (_crossed) {
        if (aV < _vMin) { _vMin = aV; _tMin = t; }
        else {
          const bool timeout = t - _tCross > kMaxRefineWaitS;
          if (aV > kReboundRel * _humpPeak || timeout) {
            const double tOut = _tMin + kTakeoffRefineS;
            uint8_t reasons = takeoffReasons(tOut) | (timeout ? R_TIMEOUT : 0);
            if (fabs(tOut - _tFastOut) > kDisagreeS) reasons |= R_DISAGREE;
            EventInfo info;
            info.confidence = conf(kConfFinalTakeoff, reasons, 0);
            info.reasons = reasons;
            info.addU8(pushIntensity());
            takeoff(toUs(tOut, t, s.timeUs), STAGE_FINAL, info);
            endContact(true, tOut, t);
          }
        }
      } else if (inContactFor > kMaxContactS) {
        endContact(false, 0.0, t);   // no clean hump/crossing: give up on this contact, report nothing
      }
      _prevAv = aV;
    }
  }

 private:
  // ---- detection constants (bed_cycle.py BedCycleParams defaults) ----
  static constexpr float kGravityTauS = 2.0f;
  static constexpr float kLowpassHz = 8.0f;        // a_v minimum is the most consistent takeoff marker at 8 Hz
  static constexpr float kGyroTauS = 0.01f;
  static constexpr float kNoiseTauS = 0.5f;
  static constexpr float kKNoise = 4.0f;           // landing: gyro > kKNoise * flight noise ...
  static constexpr float kKContact = 0.3f;         // ... and > kKContact * typical contact gyro peak ...
  static constexpr float kKRing = 2.5f;            // ... and > kKRing * decaying envelope ~60 ms ago
  static constexpr float kRingTauS = 0.15f;
  static constexpr float kContactLevelAlpha = 0.3f;
  static constexpr float kOnsetKNoise = 2.0f;
  static constexpr float kOnsetLookbackS = 0.06f;
  static constexpr float kLandPeakWinS = 0.08f;    // final landing emitted this long after detection
  static constexpr float kHumpMinG = 0.5f;
  static constexpr float kCrossRel = 0.2f;
  static constexpr float kMinTakeoffAfterS = 0.22f;   // contacts last 0.33-0.64 s; keep this loose (>=0.28 breaks)
  static constexpr float kReboundRel = 0.3f;
  static constexpr float kMaxRefineWaitS = 0.2f;   // keeps the final takeoff within the 200 ms deadline
  static constexpr float kMaxContactS = 0.8f;
  static constexpr float kMinFlightS = 0.15f;
  static constexpr float kWarmupS = 0.5f;
  static constexpr int kDesignSamples = 32;
  static constexpr int kBufMax = 160;
  // ---- event extras ----
  static constexpr float kRefAlpha = 0.2f;
  static constexpr float kWeakPushRel = 0.5f;
  static constexpr float kContactMinS = 0.25f, kContactMaxS = 0.7f;
  static constexpr float kDisagreeS = 0.06f;
  static constexpr float kGapFactor = 2.5f;
  static constexpr float kClipG = 15.5f;
  static constexpr int kConfProvisionalLanding = 70, kConfFinalLanding = 90;
  static constexpr int kConfProvisionalTakeoff = 60, kConfFinalTakeoff = 90;
  static constexpr float kLowMarginRatio = 1.5f;
  static constexpr int kLowMarginPenalty = 15;
  static constexpr uint8_t kNa = 255;
  enum : uint8_t {
    R_DISAGREE = 1 << 0, R_TIMEOUT = 1 << 1, R_WEAK_PUSH = 1 << 2, R_CONTACT_RANGE = 1 << 3,
    R_SAMPLES_LOST = 1 << 4, R_CLIPPED = 1 << 5, R_WARMUP = 1 << 6
  };
  // ---- timing constants, calibrated on both batch-3 recordings (calibrate_timing()).
  //      IN-vs-OUT differences are sync-independent; absolute values carry the
  //      video sync's error (~+-50 ms). Recalibrate on batch 4.
  static constexpr float kLandingFastS = 0.0243f;     // subtracted
  static constexpr float kLandingRefineS = -0.0243f;  // added
  static constexpr float kTakeoffFastS = 0.0835f;     // added
  static constexpr float kTakeoffRefineS = -0.0404f;  // added

  struct Entry { double t; float gyr; float env; };

  static uint8_t conf(int base, uint8_t reasons, int extraPenalty) {
    static const int penalty[7] = {30, 40, 20, 25, 30, 20, 20};  // per reason bit, heuristic
    int c = base - extraPenalty;
    for (int i = 0; i < 7; i++) if (reasons & (1 << i)) c -= penalty[i];
    return (uint8_t)(c < 5 ? 5 : (c > 100 ? 100 : c));
  }
  static uint8_t relU8(float value, bool haveRef, float ref) {
    if (!haveRef || ref <= 0.0f) return kNa;
    const float x = floorf(100.0f * value / ref + 0.5f);
    return (uint8_t)(x < 0.0f ? 0.0f : (x > 254.0f ? 254.0f : x));
  }
  uint8_t pushIntensity() const { return relU8(_humpPeak, _haveHumpRef, _humpRef); }

  uint8_t takeoffReasons(double tOut) const {
    uint8_t r = 0;
    if (_haveHumpRef && _humpPeak < kWeakPushRel * _humpRef) r |= R_WEAK_PUSH;
    if (_haveOnset && (tOut - _onset < kContactMinS || tOut - _onset > kContactMaxS)) r |= R_CONTACT_RANGE;
    if (_contactGap) r |= R_SAMPLES_LOST;
    if (_contactClip) r |= R_CLIPPED;
    if (!_haveContactLevel) r |= R_WARMUP;
    return r;
  }

  // 2nd-order Butterworth low-pass (bilinear, prewarped == scipy butter(2, fc)), DF2T
  void designFilter(float dtAvg) {
    const float fs = 1.0f / dtAvg;
    const float k = tanf(3.14159265358979f * kLowpassHz / fs);
    const float k2 = k * k;
    const float sq2 = 1.41421356237f;
    const float norm = 1.0f / (1.0f + sq2 * k + k2);
    _b0 = k2 * norm;
    _b1 = 2.0f * _b0;
    _b2 = _b0;
    _a1 = 2.0f * (k2 - 1.0f) * norm;
    _a2 = (1.0f - sq2 * k + k2) * norm;
    _z1 = _z2 = 0.0f;
    _dtRef = dtAvg;
    const int n = (int)(kOnsetLookbackS / dtAvg) + 1;
    _bufLen = n < 2 ? 2 : (n > kBufMax ? kBufMax : n);
    _bufHead = _bufCount = 0;
    _designed = true;
  }
  float biquad(float x) {
    const float y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  // ring buffer, oldest at index 0
  void push(double t, float gyr, float env) {
    const int idx = (_bufHead + _bufCount) % _bufLen;
    _buf[idx] = Entry{t, gyr, env};
    if (_bufCount < _bufLen) _bufCount++;
    else _bufHead = (_bufHead + 1) % _bufLen;
  }
  const Entry& at(int i) const { return _buf[(_bufHead + i) % _bufLen]; }

  void resetContact() {
    _humpPeak = 0.0f;
    _crossed = false;
    _haveZero = false;
    _tZero = 0.0;
    _vMin = 1e30f;
    _tMin = 0.0;
    _tCross = 0.0;
    _tFastOut = 0.0;
    _contactGyroPeak = 0.0f;
    _prevAv = 0.0f;
    _pendingOnset = false;
    _haveOnset = false;
    _onset = 0.0;
    _landFinalDue = false;
    _landPeak = 0.0f;
    _landGap = _landClip = false;
    _landReasons = 0;
    _landPenalty = 0;
    _contactGap = _contactClip = false;
    _reportLanding = true;
  }

  void endContact(bool refined, double tOut, double tNow) {
    if (!_haveContactLevel) { _contactLevel = _contactGyroPeak; _haveContactLevel = true; }
    else _contactLevel += kContactLevelAlpha * (_contactGyroPeak - _contactLevel);
    if (refined) {
      if (!_haveHumpRef) { _humpRef = _humpPeak; _haveHumpRef = true; }
      else _humpRef += kRefAlpha * (_humpPeak - _humpRef);
    }
    _inContact = false;
    _tState = tNow;
    _tLastOut = refined ? tOut : tNow;
    _gapFlight = false;
  }

  // Detector time tEvent -> microseconds on the s.timeUs clock, by difference to
  // the current sample (tNow <-> nowUs); tEvent may lie in the future.
  static uint64_t toUs(double tEvent, double tNow, uint64_t nowUs) {
    const double deltaUs = (tNow - tEvent) * 1e6;
    if (deltaUs >= 0.0) {
      const uint64_t d = (uint64_t)(deltaUs + 0.5);
      return (d < nowUs) ? nowUs - d : 0;
    }
    return nowUs + (uint64_t)(-deltaUs + 0.5);
  }

  // ---- state ----
  double _t = 0.0, _dtSum = 0.0;
  int _nSamples = 0;
  float _dtRef = 0.0f;
  bool _designed = false;
  float _b0 = 0, _b1 = 0, _b2 = 0, _a1 = 0, _a2 = 0, _z1 = 0, _z2 = 0;
  bool _haveG = false;
  float _gx = 0, _gy = 0, _gz = 0;
  float _gyr = 0, _env = 0;
  bool _haveNoise = false;
  float _noise = 0;
  bool _haveContactLevel = false;
  float _contactLevel = 0;
  bool _haveHumpRef = false, _haveLandRef = false;
  float _humpRef = 0, _landRef = 0;
  Entry _buf[kBufMax];
  int _bufLen = 2, _bufHead = 0, _bufCount = 0;
  bool _inContact = false, _awaitingTakeoff = true, _gapFlight = false;
  double _tState = -1e9, _tLastOut = -1e9;
  // per contact
  float _humpPeak = 0;
  bool _crossed = false, _haveZero = false;
  double _tZero = 0.0, _tMin = 0.0, _tCross = 0.0, _tFastOut = 0.0;
  float _vMin = 1e30f, _contactGyroPeak = 0, _prevAv = 0;
  bool _pendingOnset = false, _haveOnset = false, _landFinalDue = false;
  double _tPendingOnset = 0.0, _onset = 0.0, _tLandFinal = 0.0;
  float _landPeak = 0;
  bool _landGap = false, _landClip = false, _contactGap = false, _contactClip = false, _reportLanding = true;
  uint8_t _landReasons = 0;
  int _landPenalty = 0;
};
