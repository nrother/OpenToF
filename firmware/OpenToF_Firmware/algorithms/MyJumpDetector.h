// ============================================================================
// ############################################################################
// #                                                                          #
// #                        YOUR ALGORITHM GOES HERE                          #
// #                                                                          #
// ############################################################################
// ============================================================================
//
// HOW TO WRITE YOUR OWN JUMP-DETECTION ALGORITHM
//
//  1. Your onSample() is called for EVERY IMU sample (about 416 or 833 times per second)
//     with the real sensor data: acceleration in g and rotation rate in deg/s.
//  2. Decide from that data whether the gymnast just LANDED on the bed or TOOK OFF.
//  3. Tell the firmware with  landing(s.timeUs)  or  takeoff(s.timeUs).
//
//  That is all. The firmware turns your calls into flight and contact times, counts the
//  sequence numbers and sends the BLE notifications to the app.
//  Set DEMO_MODE 0 (FirmwareConfig.h, default) so the IMU is used, and IMU_SERIAL_LOG 1 to
//  watch the raw data.
//
// Several algorithms: copy this file to e.g. MyOtherDetector.h, rename the class, and add a
// block for it in the "Algorithm selection" comment at the top of the .ino.
//
// Rules of the game
//  - Report events in order: takeoff, landing, takeoff, landing, ...
//    (A landing without an earlier takeoff, and a takeoff while already airborne, are
//     ignored by the firmware, so it is fine to start "in the middle".)
//  - Flight time = landing time - takeoff time; contact time = takeoff time - previous landing.
//    The precision of those times is the precision of the timestamps you pass in.
//  - onSample() runs ~416 or ~833 times per second. Keep it fast: no delay(), no
//    Serial printing, no long loops. Plain float maths is fine.
//  - Keep any state (filters, timers, flags) in the private members below.
//  - See what the data looks like first: set IMU_SERIAL_LOG 1 in FirmwareConfig.h and watch the
//    Serial Monitor / Serial Plotter while someone bounces.
#pragma once

#include <math.h>

#include "../core/JumpDetector.h"

class MyJumpDetector : public JumpDetector {
 public:
  // Shown over BLE (Software Revision String, max 32 bytes). Add a version when you change
  // the algorithm, e.g. "MyJumpDetector v2".
  const char* name() const override { return "MyJumpDetector"; }

  // OPTIONAL: pick the IMU settings your algorithm needs (default: IMU_USE_HIGH_RATE_PROFILE).
  // const ImuProfile& imuProfile() const override { return PROFILE_833HZ_16G; }

  // Called once at start-up. Reset your state.
  void begin() override {
    _onBed = false;
    _envelope = 0.0f;
  }

  // Called for every IMU sample. This is the function to write.
  void onSample(const ImuData& s) override {
    // s.timeUs                : timestamp in microseconds
    // s.dt                    : seconds since the previous sample
    // s.ax, s.ay, s.az        : acceleration in g
    // s.gx, s.gy, s.gz        : rotation rate in degrees per second
    // s.accelMagnitude()      : length of the acceleration vector in g
    // s.gyroMagnitude()       : length of the rotation-rate vector in deg/s

    // ---- YOUR CODE: 1) compute features from the data, 2) decide, 3) report ----
    //
    // Example of the pattern (an ILLUSTRATION with made-up thresholds, NOT a tested detector):

    // 1) feature: how strongly does the frame vibrate? (deviation from gravity, smoothed)
    float vibration = fabsf(s.accelMagnitude() - 1.0f);
    _envelope += 0.05f * (vibration - _envelope);

    // 2+3) decide with hysteresis (different thresholds up and down) and report
    if (!_onBed && _envelope > 0.30f) {
      _onBed = true;
      landing(s.timeUs);  // vibration started: the gymnast hit the bed
    } else if (_onBed && _envelope < 0.10f) {
      _onBed = false;
      takeoff(s.timeUs);  // vibration stopped: the gymnast left the bed
    }
  }

 private:
  // ---- YOUR STATE ----
  bool _onBed = false;
  float _envelope = 0.0f;
};
