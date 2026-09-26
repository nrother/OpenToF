// Demo source: simulated bouncing, no IMU involved (DEMO_MODE 1).
// Sends every takeoff/landing in two stages like a real two-stage algorithm: a provisional
// estimate shortly after the event (a few ms off) and the exact final one later, with
// confidence, an occasional reason bit and the two intensity fields. Now and then it also
// reports a false provisional landing mid-flight and retracts it.
#pragma once

#include <Arduino.h>

#include "../config/FirmwareConfig.h"
#include "Micros64.h"
#include "Transition.h"

class DemoSource : public TransitionSource {
 public:
  const char* name() const override { return "Demo (simulated jumps)"; }
  const char* fieldsJson() const override {
    return "[{\"id\":\"pi\",\"name\":\"Push-off intensity\",\"t\":\"u8\",\"on\":\"T\",\"rel\":true,"
           "\"na\":255,\"desc\":\"Strength of the push-off before this takeoff\"},"
           "{\"id\":\"li\",\"name\":\"Landing intensity\",\"t\":\"u8\",\"on\":\"L\",\"rel\":true,"
           "\"na\":255,\"desc\":\"How hard the landing hit the bed\"}]";
  }
  const char* reasonsJson() const override { return "[\"demo: simulated uncertainty\"]"; }
  const char* confidenceKind() const override { return "heuristic"; }

  void begin() {
    _state = ON_BED;
    _nextPhysicalUs = micros64() + (uint64_t)DEMO_START_DELAY_MS * 1000ULL;
    _jumpsInBurst = 0;
    _count = 0;
    _head = 0;
  }

  bool poll(Transition& out) override {
    const uint64_t now = micros64();
    if (_count == 0 && now >= _nextPhysicalUs) simulateNextPhysicalEvent();
    if (_count == 0 || now < _queue[_head].dueUs) return false;
    out = _queue[_head].t;
    _head = (_head + 1) % QUEUE_SIZE;
    _count--;
    return true;
  }

 private:
  enum State { IN_AIR, ON_BED };
  struct Pending {
    uint64_t dueUs;  // when to hand it out
    Transition t;
  };
  static const int QUEUE_SIZE = 8;

  State _state = ON_BED;
  uint64_t _nextPhysicalUs = 0;
  uint16_t _jumpsInBurst = 0;
  Pending _queue[QUEUE_SIZE];
  int _head = 0;
  int _count = 0;

  // Queued in due-time order: every physical event's reports are due before the next one.
  void enqueue(uint64_t dueUs, TransitionType type, EventStage stage, bool retract,
               uint64_t timeUs, const EventInfo& info) {
    if (_count >= QUEUE_SIZE) return;
    Pending& p = _queue[(_head + _count) % QUEUE_SIZE];
    p.dueUs = dueUs;
    p.t.type = type;
    p.t.stage = stage;
    p.t.retract = retract;
    p.t.timeUs = timeUs;
    p.t.info = info;
    _count++;
  }

  static uint64_t ms(long v) { return (uint64_t)v * 1000ULL; }

  // Queues the provisional + final report of one event at time `at`.
  void reportTwoStage(TransitionType type, uint64_t at, uint64_t finalDelayUs) {
    EventInfo provisional;
    provisional.confidence = (uint8_t)random(50, 81);
    provisional.addU8(255);  // intensity not known yet
    const uint64_t off = ms(random(0, 9));
    const uint64_t provisionalTime = random(2) ? at + off : at - off;
    enqueue(at + ms(10), type, STAGE_PROVISIONAL, false, provisionalTime, provisional);

    EventInfo final_;
    final_.confidence = (uint8_t)random(80, 101);
    if (random(10) == 0) {
      final_.confidence = (uint8_t)random(30, 60);
      final_.reasons = 1;
    }
    final_.addU8((uint8_t)random(60, 230));
    enqueue(at + finalDelayUs, type, STAGE_FINAL, false, at, final_);
  }

  void simulateNextPhysicalEvent() {
    const uint64_t at = _nextPhysicalUs;
    if (_state == ON_BED) {
      const uint64_t flightUs = ms(random(1000, 1600));
      reportTwoStage(TRANSITION_TAKEOFF, at, ms(random(80, 111)));
      if (random(15) == 0) {  // false landing mid-flight, withdrawn 60 ms later
        const uint64_t fake = at + flightUs / 2;
        EventInfo info;
        info.confidence = (uint8_t)random(20, 50);
        info.addU8(255);
        enqueue(fake, TRANSITION_LANDING, STAGE_PROVISIONAL, false, fake, info);
        enqueue(fake + ms(60), TRANSITION_LANDING, STAGE_PROVISIONAL, true, 0, EventInfo());
      }
      _state = IN_AIR;
      _nextPhysicalUs = at + flightUs;
    } else {
      reportTwoStage(TRANSITION_LANDING, at, ms(random(30, 121)));
      _state = ON_BED;
      if (++_jumpsInBurst >= DEMO_BURST_JUMPS) {
        _jumpsInBurst = 0;
        _nextPhysicalUs = at + ms(DEMO_REST_MS);  // standing still
      } else {
        _nextPhysicalUs = at + ms(random(150, 250));  // bed contact
      }
    }
  }
};
