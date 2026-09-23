// Demo source: simulated bouncing, no IMU involved (DEMO_MODE 1).
#pragma once

#include <Arduino.h>

#include "../config/FirmwareConfig.h"
#include "Micros64.h"
#include "Transition.h"

class DemoSource : public TransitionSource {
 public:
  const char* name() const { return "Demo (simulated jumps)"; }

  void begin() {
    _state = WAIT_FIRST_TAKEOFF;
    _nextAtUs = micros64() + (uint64_t)DEMO_START_DELAY_MS * 1000ULL;
    _jumpsInBurst = 0;
  }

  bool poll(Transition& out) override {
    const uint64_t now = micros64();
    if (now < _nextAtUs) return false;

    out.timeUs = _nextAtUs;  // report the scheduled time, not the poll time
    switch (_state) {
      case WAIT_FIRST_TAKEOFF:
      case ON_BED:
        out.type = TRANSITION_TAKEOFF;
        _state = IN_AIR;
        _nextAtUs += (uint64_t)random(1000, 1600) * 1000ULL;  // flight time
        break;
      case IN_AIR:
        out.type = TRANSITION_LANDING;
        _state = ON_BED;
        if (++_jumpsInBurst >= DEMO_BURST_JUMPS) {
          _jumpsInBurst = 0;
          _nextAtUs += (uint64_t)DEMO_REST_MS * 1000ULL;  // standing still
        } else {
          _nextAtUs += (uint64_t)random(150, 250) * 1000ULL;  // bed contact
        }
        break;
    }
    return true;
  }

 private:
  enum State { WAIT_FIRST_TAKEOFF, IN_AIR, ON_BED };
  State _state = WAIT_FIRST_TAKEOFF;
  uint64_t _nextAtUs = 0;
  uint16_t _jumpsInBurst = 0;
};
