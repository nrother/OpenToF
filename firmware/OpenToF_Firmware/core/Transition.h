// A takeoff/landing transition and the interface of anything that produces them
// (the real IMU pipeline in ImuSource.h, the simulator in DemoSource.h).
#pragma once

#include <stdint.h>

enum TransitionType : uint8_t { TRANSITION_TAKEOFF, TRANSITION_LANDING };

struct Transition {
  TransitionType type;
  uint64_t timeUs;  // when it happened (device time)
};

class TransitionSource {
 public:
  virtual ~TransitionSource() {}
  // Returns true and fills `out` if a transition happened. Must not block.
  virtual bool poll(Transition& out) = 0;
};
