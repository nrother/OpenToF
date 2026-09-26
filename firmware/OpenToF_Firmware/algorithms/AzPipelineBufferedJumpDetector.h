// ============================================================================
// AzPipelineBufferedJumpDetector -- wraps docs/reference/batch3/OpenToF_MG24_Buffer_Online.cpp
// (given, not derived) into the JumpDetector interface.
//
// Third design point in the az-pipeline family (see
// experiments/batch3_mg24/README.md, "A second reference implementation"): same
// zone -> merge -> expand-to-zero -> dip -> 2nd-max detection as the offline
// pipeline (not a simplified causal proxy like AzPipelineJumpDetector.h's), made
// implementable on-device via:
//   1. filtfilt -> a 201-tap *linear-phase* FIR, applied causally. A symmetric FIR
//      has an exactly constant group delay ((201-1)/2 = 100 samples, ~240ms at
//      416Hz) at every frequency -- unlike a causal IIR (AzPipelineJumpDetector.h's
//      Butterworth), whose delay varies with frequency and is only approximately
//      correctable, this constant delay can be *exactly* subtracted back out of
//      every detected timestamp. That's the whole trick, and it's why this design
//      gets ~8ms timing error (src/opentof_research/detectors/az_pipeline.py (process_buffered),
//      matching this file almost line for line) against the plain online version's
//      76ms.
//   2. Detection runs retrospectively over a ~3.85s circular buffer instead of
//      needing the whole recording.
// Cost: a real, measured delay -- the FIR's fixed ~240ms, plus however long it takes
// to see the *next* jump's landing (a takeoff isn't reported as real until the
// flight after it is also confirmed). Measured at ~900ms-1.3s on the reference
// recordings (experiments/batch3_mg24/README.md) -- longer than the ~700ms this was
// designed around, because that number is inherently session-dependent (it shrinks
// for faster bouncing, grows for slower).
//
// v2 (algorithm interface v1): input resampled to an exact 416 Hz grid (the MCU
// delivers ~285 samples/s with jitter), 16 g profile, explicit FINAL events. Its
// ~1 s reporting delay violates the interface's 200 ms final deadline -- see
// onSample(); not suitable for live feedback.
//
// Only real changes from the given .cpp:
//   - Its internal `JumpDetector` class is renamed `AzBufferedZoneDetector` --
//     that name collides with this firmware's actual JumpDetector base class
//     (../core/JumpDetector.h) once both are visible in the same translation unit.
//     Everything else in the ported classes is unchanged (same constants, same
//     zone/merge/dip/2nd-max logic, same FIR taps -- verified bit-for-bit against
//     `scipy.signal.firwin(201, 5.0/(416/2))` before being trusted).
//   - `popNextJump()` results (a takeoff sample index + a flight duration) are
//     translated into this interface's separate `takeoff()`/`landing()` calls --
//     see the wrapper class at the bottom for how, and why a small parallel ring
//     buffer of real timestamps is needed to do that correctly.
// ============================================================================
#pragma once

#include <math.h>
#include <string.h>
#include <stdint.h>

#include "../core/JumpDetector.h"

// ============================================================================
// Parameters (unchanged from the given .cpp)
// ============================================================================
static constexpr float  AZBUF_FS                    = 416.0f;
static constexpr int    AZBUF_MEDIAN_WINDOW         = 7;
static constexpr int    AZBUF_FIR_TAPS_N            = 201;
static constexpr int    AZBUF_FIR_DELAY             = (AZBUF_FIR_TAPS_N - 1) / 2;  // 100
static constexpr int    AZBUF_TOTAL_TIME_OFFSET     = AZBUF_FIR_DELAY + 2;          // 102

static constexpr float  AZBUF_DETECT_THRESH         = 0.3f;   // g, coarse contact detection
static constexpr float  AZBUF_ZERO_THRESH           = 0.05f;  // g, a~0
static constexpr float  AZBUF_PEAK_HEIGHT           = 0.15f;  // g, minimum peak height for the 2nd max
static constexpr int    AZBUF_MIN_CONTACT_SAMPLES   = 20;
static constexpr int    AZBUF_MIN_FLIGHT_SAMPLES    = 50;
static constexpr int    AZBUF_MERGE_GAP             = 80;
static constexpr int    AZBUF_LANDING_CORR_SAMPLES  = 15;     // +35ms
static constexpr int    AZBUF_ONLINE_CORR_SAMPLES   = 2;      // +5ms, median-filter delay allowance

static constexpr int    AZBUF_GRAVITY_CALIB_SAMPLES = 500;
static constexpr int    AZBUF_MAX_UNREAD_JUMPS      = 64;
static constexpr int    AZBUF_ALIGN_SIZE            = 1600;   // ~3.85s at 416Hz

// ============================================================================
// FIR coefficients -- scipy.signal.firwin(201, 5.0/(416/2)); verified to match
// docs/reference/batch3/OpenToF_MG24_Buffer_Online.cpp's hardcoded table bit-for-bit
// (see src/opentof_research/detectors/az_pipeline.py (process_buffered)).
// ============================================================================
static const float AZBUF_FIR_TAPS[AZBUF_FIR_TAPS_N] = {
    2.4262018542e-04f, 2.3928769912e-04f, 2.3579065617e-04f, 2.3199748068e-04f, 2.2773425837e-04f, 2.2278625538e-04f, 2.1690018860e-04f, 2.0978723942e-04f,
    2.0112679360e-04f, 1.9057088100e-04f, 1.7774927961e-04f, 1.6227523991e-04f, 1.4375177680e-04f, 1.2177846861e-04f, 9.5958695073e-05f, 6.5907239318e-05f,
    3.1258172846e-05f, -8.3270630924e-06f, -5.3151470685e-05f, -1.0347429803e-04f, -1.5950292825e-04f, -2.2138495420e-04f, -2.8920053866e-04f, -3.6295515897e-04f,
    -4.4257283415e-04f, -5.2788992950e-04f, -6.1864963043e-04f, -7.1449717226e-04f, -8.1497590724e-04f, -9.1952428351e-04f, -1.0274738027e-03f, -1.1380480149e-03f,
    -1.2503626008e-03f, -1.3634265791e-03f, -1.4761446705e-03f, -1.5873208334e-03f, -1.6956629805e-03f, -1.7997888695e-03f, -1.8982331512e-03f, -1.9894555463e-03f,
    -2.0718501101e-03f, -2.1437555318e-03f, -2.2034664045e-03f, -2.2492453918e-03f, -2.2793362038e-03f, -2.2919772879e-03f, -2.2854161303e-03f, -2.2579240539e-03f,
    -2.2078113939e-03f, -2.1334429232e-03f, -2.0332533973e-03f, -1.9057630814e-03f, -1.7495931222e-03f, -1.5634806236e-03f, -1.3462932857e-03f, -1.0970434686e-03f,
    -8.1490154228e-04f, -4.9920839050e-04f, -1.4948693979e-04f, 2.3454740903e-04f, 6.5297756112e-04f, 1.1056768261e-03f, 1.5923024309e-03f, 2.1122905336e-03f,
    2.6648528104e-03f, 3.2489746798e-03f, 3.8634152100e-03f, 4.5067087450e-03f, 5.1771682706e-03f, 5.8728905230e-03f, 6.5917628338e-03f, 7.3314716848e-03f,
    8.0895129339e-03f, 8.8632036583e-03f, 9.6496955465e-03f, 1.0445989756e-02f, 1.1248953139e-02f, 1.2055335737e-02f, 1.2861789404e-02f, 1.3664887456e-02f,
    1.4461145170e-02f, 1.5247041022e-02f, 1.6019038469e-02f, 1.6773608144e-02f, 1.7507250272e-02f, 1.8216517148e-02f, 1.8898035499e-02f, 1.9548528568e-02f,
    2.0164837720e-02f, 2.0743943434e-02f, 2.1282985494e-02f, 2.1779282220e-02f, 2.2230348599e-02f, 2.2633913153e-02f, 2.2987933425e-02f, 2.3290609951e-02f,
    2.3540398602e-02f, 2.3736021205e-02f, 2.3876474356e-02f, 2.3961036336e-02f, 2.3989272112e-02f, 2.3961036336e-02f, 2.3876474356e-02f, 2.3736021205e-02f,
    2.3540398602e-02f, 2.3290609951e-02f, 2.2987933425e-02f, 2.2633913153e-02f, 2.2230348599e-02f, 2.1779282220e-02f, 2.1282985494e-02f, 2.0743943434e-02f,
    2.0164837720e-02f, 1.9548528568e-02f, 1.8898035499e-02f, 1.8216517148e-02f, 1.7507250272e-02f, 1.6773608144e-02f, 1.6019038469e-02f, 1.5247041022e-02f,
    1.4461145170e-02f, 1.3664887456e-02f, 1.2861789404e-02f, 1.2055335737e-02f, 1.1248953139e-02f, 1.0445989756e-02f, 9.6496955465e-03f, 8.8632036583e-03f,
    8.0895129339e-03f, 7.3314716848e-03f, 6.5917628338e-03f, 5.8728905230e-03f, 5.1771682706e-03f, 4.5067087450e-03f, 3.8634152100e-03f, 3.2489746798e-03f,
    2.6648528104e-03f, 2.1122905336e-03f, 1.5923024309e-03f, 1.1056768261e-03f, 6.5297756112e-04f, 2.3454740903e-04f, -1.4948693979e-04f, -4.9920839050e-04f,
    -8.1490154228e-04f, -1.0970434686e-03f, -1.3462932857e-03f, -1.5634806236e-03f, -1.7495931222e-03f, -1.9057630814e-03f, -2.0332533973e-03f, -2.1334429232e-03f,
    -2.2078113939e-03f, -2.2579240539e-03f, -2.2854161303e-03f, -2.2919772879e-03f, -2.2793362038e-03f, -2.2492453918e-03f, -2.2034664045e-03f, -2.1437555318e-03f,
    -2.0718501101e-03f, -1.9894555463e-03f, -1.8982331512e-03f, -1.7997888695e-03f, -1.6956629805e-03f, -1.5873208334e-03f, -1.4761446705e-03f, -1.3634265791e-03f,
    -1.2503626008e-03f, -1.1380480149e-03f, -1.0274738027e-03f, -9.1952428351e-04f, -8.1497590724e-04f, -7.1449717226e-04f, -6.1864963043e-04f, -5.2788992950e-04f,
    -4.4257283415e-04f, -3.6295515897e-04f, -2.8920053866e-04f, -2.2138495420e-04f, -1.5950292825e-04f, -1.0347429803e-04f, -5.3151470685e-05f, -8.3270630924e-06f,
    3.1258172846e-05f, 6.5907239318e-05f, 9.5958695073e-05f, 1.2177846861e-04f, 1.4375177680e-04f, 1.6227523991e-04f, 1.7774927961e-04f, 1.9057088100e-04f,
    2.0112679360e-04f, 2.0978723942e-04f, 2.1690018860e-04f, 2.2278625538e-04f, 2.2773425837e-04f, 2.3199748068e-04f, 2.3579065617e-04f, 2.3928769912e-04f,
    2.4262018542e-04f
};

// ============================================================================
// Stage 1: causal median(7) -- unchanged from the given .cpp
// ============================================================================
class AzBufMedianFilter {
 public:
  AzBufMedianFilter() { reset(); }
  void reset() { memset(m_buffer, 0, sizeof(m_buffer)); m_idx = 0; }
  float process(float input) {
    m_buffer[m_idx] = input;
    m_idx = (m_idx + 1) % AZBUF_MEDIAN_WINDOW;
    float sorted[AZBUF_MEDIAN_WINDOW];
    memcpy(sorted, m_buffer, sizeof(sorted));
    for (int i = 1; i < AZBUF_MEDIAN_WINDOW; ++i) {
      float key = sorted[i];
      int j = i - 1;
      while (j >= 0 && sorted[j] > key) { sorted[j + 1] = sorted[j]; --j; }
      sorted[j + 1] = key;
    }
    return sorted[AZBUF_MEDIAN_WINDOW / 2];
  }
 private:
  float m_buffer[AZBUF_MEDIAN_WINDOW];
  int   m_idx;
};

// ============================================================================
// Stage 2: causal 201-tap FIR low-pass -- unchanged from the given .cpp
// ============================================================================
class AzBufFIRFilter {
 public:
  AzBufFIRFilter() { reset(); }
  void reset() { memset(m_buffer, 0, sizeof(m_buffer)); m_idx = 0; }
  float process(float input) {
    m_buffer[m_idx] = input;
    float acc = 0.0f;
    int i = m_idx;
    for (int k = 0; k < AZBUF_FIR_TAPS_N; ++k) {
      acc += AZBUF_FIR_TAPS[k] * m_buffer[i];
      if (--i < 0) i += AZBUF_FIR_TAPS_N;
    }
    ++m_idx;
    if (m_idx >= AZBUF_FIR_TAPS_N) m_idx = 0;
    return acc;
  }
 private:
  float m_buffer[AZBUF_FIR_TAPS_N];
  int   m_idx;
};

// ============================================================================
// Result of one resolved flight -- unchanged shape from the given .cpp's
// JumpResult, renamed to avoid any ambiguity with other detectors' types.
// ============================================================================
struct AzBufFlightResult {
  uint32_t sample_index;   // takeoff instant, in *filter-delay-corrected* samples
  float    flight_ms;      // flight duration in ms (delay-invariant -- see file header)
  bool     valid;
};

// ============================================================================
// Stage 3: retrospective detection over a circular buffer of the filtered signal.
// Renamed from the given .cpp's `JumpDetector` -- that name collides with this
// firmware's actual JumpDetector base class (../core/JumpDetector.h) once both are
// visible in the same translation unit. Logic is otherwise unchanged.
// ============================================================================
class AzBufferedZoneDetector {
 public:
  AzBufferedZoneDetector() { reset(); }
  void reset() {
    memset(m_buffer, 0, sizeof(m_buffer));
    m_write_idx = 0;
    m_total = 0;
    m_num_jumps = 0;
    m_read_idx = 0;
    m_last_resolved = 0;
    m_in_zone = false;
  }

  void push_delayed(float az) {
    m_buffer[m_write_idx] = az;
    m_write_idx = (m_write_idx + 1) % AZBUF_ALIGN_SIZE;
    ++m_total;

    bool above = fabsf(az) > AZBUF_DETECT_THRESH;
    if (above && !m_in_zone) {
      m_in_zone = true;
    } else if (!above && m_in_zone) {
      m_in_zone = false;
      run_detection();
    }
  }

  bool popNextJump(AzBufFlightResult &out) {
    if (m_read_idx >= m_num_jumps) return false;
    out = m_jumps[m_read_idx % AZBUF_MAX_UNREAD_JUMPS];
    ++m_read_idx;
    return true;
  }

  int getNumUnread() const { return m_num_jumps - m_read_idx; }

 private:
  float value_at(uint32_t idx) const { return m_buffer[idx % AZBUF_ALIGN_SIZE]; }

  void storeJump(const AzBufFlightResult &r) {
    if (getNumUnread() >= AZBUF_MAX_UNREAD_JUMPS) {
      ++m_read_idx;
      if (m_read_idx > m_num_jumps) m_read_idx = m_num_jumps;
    }
    m_jumps[m_num_jumps % AZBUF_MAX_UNREAD_JUMPS] = r;
    ++m_num_jumps;
  }

  void run_detection() {
    if (m_total < (uint32_t)AZBUF_MIN_FLIGHT_SAMPLES) return;

    uint32_t oldest = (m_total > (uint32_t)AZBUF_ALIGN_SIZE) ? (m_total - (uint32_t)AZBUF_ALIGN_SIZE) : 0;
    uint32_t newest = m_total - 1;

    struct Zone { uint32_t start, end; };
    Zone zones[64];
    uint32_t n_zones = 0;
    bool in_zone = false;
    uint32_t zstart = 0;

    for (uint32_t i = oldest + 1; i <= newest; ++i) {
      bool above = fabsf(value_at(i)) > AZBUF_DETECT_THRESH;
      if (above && !in_zone) { in_zone = true; zstart = i; }
      else if (!above && in_zone) {
        uint32_t zend = i - 1;
        if (zend - zstart >= (uint32_t)AZBUF_MIN_CONTACT_SAMPLES && n_zones < 64) {
          zones[n_zones].start = zstart; zones[n_zones].end = zend; ++n_zones;
        }
        in_zone = false;
      }
    }
    if (in_zone) {
      uint32_t zend = newest;
      if (zend - zstart >= (uint32_t)AZBUF_MIN_CONTACT_SAMPLES && n_zones < 64) {
        zones[n_zones].start = zstart; zones[n_zones].end = zend; ++n_zones;
      }
    }

    struct MZone { uint32_t start, end; };
    MZone mz[64];
    uint32_t n_mz = 0;
    for (uint32_t z = 0; z < n_zones; ++z) {
      if (n_mz && zones[z].start - mz[n_mz - 1].end < (uint32_t)AZBUF_MERGE_GAP) {
        mz[n_mz - 1].end = zones[z].end;
      } else {
        mz[n_mz].start = zones[z].start; mz[n_mz].end = zones[z].end; ++n_mz;
      }
    }

    struct Contact { uint32_t landing, takeoff; };
    Contact contacts[64];
    uint32_t n_contacts = 0;
    for (uint32_t z = 0; z < n_mz; ++z) {
      uint32_t ls = mz[z].start;
      while (ls > oldest && fabsf(value_at(ls)) > AZBUF_ZERO_THRESH) --ls;

      uint32_t search_end = mz[z].end;
      while (search_end < newest && fabsf(value_at(search_end)) > AZBUF_ZERO_THRESH) ++search_end;
      if (search_end > newest) search_end = newest;

      uint32_t min_idx = ls;
      float min_val = value_at(ls);
      bool saw_dip = false;
      for (uint32_t i = ls; i <= search_end; ++i) {
        float v = value_at(i);
        if (v < min_val) { min_val = v; min_idx = i; }
        if (v < -AZBUF_ZERO_THRESH) saw_dip = true;
      }
      if (!saw_dip) continue;

      uint32_t max2 = min_idx;
      float max2_val = -1e9f;
      for (uint32_t i = min_idx; i <= search_end; ++i) {
        if (value_at(i) > max2_val) { max2_val = value_at(i); max2 = i; }
      }
      if (max2_val < AZBUF_PEAK_HEIGHT) continue;

      if (n_contacts < 64) {
        contacts[n_contacts].landing = ls; contacts[n_contacts].takeoff = max2; ++n_contacts;
      }
    }

    for (uint32_t i = 0; i + 1 < n_contacts; ++i) {
      uint32_t to = contacts[i].takeoff;
      uint32_t ld_raw = contacts[i + 1].landing;
      uint32_t ld = ld_raw + (uint32_t)(AZBUF_LANDING_CORR_SAMPLES + AZBUF_ONLINE_CORR_SAMPLES);
      int32_t fl = (int32_t)(ld - to);
      if (fl > AZBUF_MIN_FLIGHT_SAMPLES && ld <= newest && ld > m_last_resolved) {
        AzBufFlightResult r;
        uint32_t to_corr = (to >= (uint32_t)AZBUF_TOTAL_TIME_OFFSET) ? (to - (uint32_t)AZBUF_TOTAL_TIME_OFFSET) : 0;
        r.sample_index = to_corr;
        r.flight_ms = (float)fl * 1000.0f / AZBUF_FS;
        r.valid = true;
        storeJump(r);
        m_last_resolved = ld;
      }
    }
  }

  float m_buffer[AZBUF_ALIGN_SIZE];
  uint32_t m_write_idx;
  uint32_t m_total;
  uint32_t m_last_resolved;
  int      m_num_jumps;
  int      m_read_idx;
  bool     m_in_zone;
  AzBufFlightResult m_jumps[AZBUF_MAX_UNREAD_JUMPS];
};

// ============================================================================
// Full pipeline: median -> FIR -> gravity subtraction -> buffered detector.
// Unchanged from the given .cpp's OpenToFPipeline, aside from the renamed member
// type.
// ============================================================================
class AzBufferedPipeline {
 public:
  AzBufferedPipeline() { reset(); }
  void reset() {
    m_median.reset();
    m_fir.reset();
    m_detector.reset();
    m_calibrated = false;
    m_calib_count = 0;
    m_calib_sum = 0.0f;
    m_gravity_z = 0.0f;
  }

  void process_sample(float az_raw_g) {
    if (!m_calibrated) {
      m_calib_sum += az_raw_g;
      ++m_calib_count;
      if (m_calib_count >= AZBUF_GRAVITY_CALIB_SAMPLES) {
        m_gravity_z = m_calib_sum / (float)AZBUF_GRAVITY_CALIB_SAMPLES;
        m_calibrated = true;
        m_median.reset();
        m_fir.reset();
      }
      return;  // NB: the calibration-completing sample itself is not pushed
    }
    float az_med = m_median.process(az_raw_g);
    float az_filt = m_fir.process(az_med);
    float az_corr = az_filt - m_gravity_z;
    m_detector.push_delayed(az_corr);
  }

  bool isCalibrated() const { return m_calibrated; }
  bool popNextJump(AzBufFlightResult &out) { return m_detector.popNextJump(out); }

 private:
  AzBufMedianFilter       m_median;
  AzBufFIRFilter          m_fir;
  AzBufferedZoneDetector  m_detector;

  bool  m_calibrated;
  int   m_calib_count;
  float m_calib_sum;
  float m_gravity_z;
};

// ============================================================================
// The actual JumpDetector: feeds every sample into AzBufferedPipeline, and turns
// each resolved AzBufFlightResult into this interface's separate takeoff()/landing()
// calls.
//
// AzBufFlightResult only carries a *sample count* (delay-corrected) and a flight
// *duration* -- not the real wall-clock timestamps landing()/takeoff() need
// (uint64_t microseconds). To recover those without assuming a perfectly even
// sample grid (see firmware/CLAUDE.md and docs/DATA_FORMAT.md on why that
// assumption is avoided elsewhere in this project), this class keeps its own small
// ring buffer of the real `s.timeUs` for every sample it hands to the pipeline,
// sized to exactly match the pipeline's own AZBUF_ALIGN_SIZE -- so any sample_index
// the pipeline can possibly report is guaranteed to still have a matching real
// timestamp recorded here. `takeoff()` is reported at that looked-up (backdated)
// time; `landing()` is derived by adding the reported flight duration on top, which
// is exactly self-consistent with how the source .cpp derives both from the same
// filter-delay-corrected quantities (see the file header comment).
// ============================================================================
class AzPipelineBufferedJumpDetector : public JumpDetector {
 public:
  const char* name() const override { return "AzPipelineBuffered v2"; }

  // Every constant above (FIR taps, MERGE_GAP, MIN_*_SAMPLES, the +102/+17 sample
  // corrections) is only valid at exactly 416 Hz. v1 therefore requested
  // PROFILE_416HZ_8G -- but the MCU does not deliver the nominal rate (the 833 Hz
  // profile yields ~285 samples/s with jitter), so the constants were silently wrong
  // on hardware. v2 resamples whatever arrives onto an exact 416 Hz grid (linear
  // interpolation on the s.timeUs clock) before the pipeline, which keeps the given
  // logic valid at any input rate -- and lets this detector use the 16 g range like
  // the others, removing v1's clipping trade-off.
  const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  void begin() override {
    _pipeline.reset();
    _sampleCounter = 0;
    _haveLast = false;
    _tickIndex = 0;
  }

  // Interface v1 usage: FINAL events only, no confidence/reasons/fields. A jump is
  // only resolved once the *next* landing has been seen, so both events arrive
  // ~0.9-1.3 s after the takeoff (FIR delay + waiting for the next contact). That
  // VIOLATES the interface's 200 ms final deadline: the app counts and beeps each
  // jump about a second late. Use this detector for logging/offline-grade timing,
  // not for live feedback.
  void onSample(const ImuData& s) override {
    if (!_haveLast) {
      _t0Us = s.timeUs;
      _nextTickUs = s.timeUs;
      _lastUs = s.timeUs;
      _lastAz = s.az;
      _haveLast = true;
    }
    // every 416 Hz tick in (last sample, this sample] -- the first call emits tick 0
    while (_nextTickUs <= s.timeUs) {
      float az = s.az;
      if (s.timeUs > _lastUs) {
        const float w = (float)(_nextTickUs - _lastUs) / (float)(s.timeUs - _lastUs);
        az = _lastAz + w * (s.az - _lastAz);
      }
      feed(az, _nextTickUs);
      _tickIndex++;
      _nextTickUs = _t0Us + (uint64_t)((double)_tickIndex * 1e6 / (double)AZBUF_FS + 0.5);
    }
    _lastUs = s.timeUs;
    _lastAz = s.az;
  }

 private:
  void feed(float az, uint64_t tickUs) {
    const bool wasCalibrated = _pipeline.isCalibrated();
    _pipeline.process_sample(az);

    if (wasCalibrated) {
      // Only record a timestamp for ticks the pipeline actually buffered --
      // process_sample() returns early (without pushing) on the very tick where
      // calibration completes, so the first pushed tick is the *next* one.
      _timeUsRing[_sampleCounter % AZBUF_ALIGN_SIZE] = tickUs;
      ++_sampleCounter;
    }

    AzBufFlightResult r;
    while (_pipeline.popNextJump(r)) {
      const uint64_t takeoffUs = _timeUsRing[r.sample_index % AZBUF_ALIGN_SIZE];
      const uint64_t landingUs = takeoffUs + (uint64_t)(r.flight_ms * 1000.0f + 0.5f);
      takeoff(takeoffUs, STAGE_FINAL);   // resolved in pairs: always on the bed here
      landing(landingUs, STAGE_FINAL);
    }
  }

  AzBufferedPipeline _pipeline;
  uint64_t _timeUsRing[AZBUF_ALIGN_SIZE];
  uint32_t _sampleCounter = 0;
  // 416 Hz resampler
  bool _haveLast = false;
  uint64_t _t0Us = 0, _nextTickUs = 0, _lastUs = 0;
  uint32_t _tickIndex = 0;
  float _lastAz = 0.0f;
};
