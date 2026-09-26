// A takeoff/landing event as reported by an algorithm, and the interface of anything that
// produces them (the real IMU pipeline in ImuSource.h, the simulator in DemoSource.h).
#pragma once

#include <stdint.h>

enum TransitionType : uint8_t { TRANSITION_TAKEOFF, TRANSITION_LANDING };

// Provisional = fast estimate (sent as early as possible), final = refined estimate
// (at most ~200 ms after the event). See JumpEventPublisher.h for the rules.
enum EventStage : uint8_t { STAGE_PROVISIONAL = 0, STAGE_FINAL = 1 };

static const uint8_t CONFIDENCE_NONE = 255;  // "the algorithm gives no confidence"
static const uint8_t EVENT_EXTRAS_MAX = 10;  // custom-field bytes per BLE event

// Optional per-event data: confidence, reason bits and the custom fields described by the
// algorithm's fieldsJson(). Custom fields are appended little-endian, in fieldsJson() order.
struct EventInfo {
  uint8_t confidence = CONFIDENCE_NONE;  // 0..100
  uint8_t reasons = 0;                   // bit i is named by reasonsJson()[i]
  uint8_t extras[EVENT_EXTRAS_MAX] = {};
  uint8_t extrasLen = 0;
  bool extrasTruncated = false;  // more than EVENT_EXTRAS_MAX bytes were added

  EventInfo& addU8(uint8_t v) { return put(v, 1); }
  EventInfo& addI8(int8_t v) { return put((uint8_t)v, 1); }
  EventInfo& addU16(uint16_t v) { return put(v, 2); }
  EventInfo& addI16(int16_t v) { return put((uint16_t)v, 2); }
  EventInfo& addU32(uint32_t v) { return put(v, 4); }
  EventInfo& addI32(int32_t v) { return put((uint32_t)v, 4); }

 private:
  EventInfo& put(uint32_t v, uint8_t bytes) {
    for (uint8_t i = 0; i < bytes; i++) {
      if (extrasLen >= EVENT_EXTRAS_MAX) {
        extrasTruncated = true;
        break;
      }
      extras[extrasLen++] = (uint8_t)(v >> (8 * i));
    }
    return *this;
  }
};

struct Transition {
  TransitionType type;
  EventStage stage;
  bool retract;     // true: withdraw the current provisional event of this type (timeUs unused)
  uint64_t timeUs;  // when it happened (device time)
  EventInfo info;
};

class TransitionSource {
 public:
  virtual ~TransitionSource() {}
  // Returns true and fills `out` if a transition happened. Must not block.
  virtual bool poll(Transition& out) = 0;

  // Algorithm description, published over BLE (see JumpDetector.h for the formats).
  virtual const char* name() const { return "unnamed"; }
  virtual const char* fieldsJson() const { return "[]"; }
  virtual const char* reasonsJson() const { return "[]"; }
  virtual const char* confidenceKind() const { return "none"; }
};
