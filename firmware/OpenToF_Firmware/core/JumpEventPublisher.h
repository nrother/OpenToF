// Turns the algorithm's takeoff/landing reports into BLE events: assigns jump ids, checks the
// provisional/final/retract rules and drops (and logs) reports that break them.
//
//   takeoff PROVISIONAL  on the bed                        -> new jump
//   takeoff FINAL        on the bed                        -> new jump
//                        or current takeoff provisional    -> finalizes it (also after the
//                           and (no landing yet or earlier    jump's landing, if its time lies
//                           than the landing)                 before that landing)
//   retractTakeoff       current takeoff provisional, no landing yet -> jump voided
//   landing PROVISIONAL  current jump has no landing       -> landing
//   landing FINAL        no landing or landing provisional -> landing / finalizes it
//   retractLanding       current landing provisional       -> back in the air
// "On the bed" = before the first takeoff, after a landing, or after a retracted takeoff.
#pragma once

#include <stdint.h>

#include "BleService.h"
#include "Logging.h"
#include "Transition.h"

static uint32_t usToMs(uint64_t us) { return (uint32_t)((us + 500) / 1000); }

class JumpEventPublisher {
 public:
  void handle(const Transition& t) {
    if (t.info.extrasTruncated) {
      LOG(String("event extras longer than ") + EVENT_EXTRAS_MAX + " bytes, truncated");
    }
    if (t.type == TRANSITION_TAKEOFF) {
      if (t.retract) retractTakeoff();
      else takeoff(t);
    } else {
      if (t.retract) retractLanding();
      else landing(t);
    }
  }

 private:
  enum Phase : uint8_t { NONE, PROVISIONAL, FINAL };

  bool _inJump = false;        // the current jump has a (not retracted) takeoff
  uint16_t _jumpId = 0;        // id of the current jump; the first jump gets 1
  Phase _takeoff = NONE;       // stage of the current jump's takeoff
  Phase _landing = NONE;       // stage of the current jump's landing
  uint64_t _landingUs = 0;     // time of the current jump's landing

  bool onBed() const { return !_inJump || _landing != NONE; }

  static void ignored(const char* why) { LOG(String("event ignored: ") + why); }

  void send(bool isLanding, uint8_t stage, uint64_t timeUs, const EventInfo& info) {
    bleNotifyEvent(_jumpId, isLanding, stage, usToMs(timeUs), info);
    static const char* const stageNames[] = {"provisional", "final", "retracted"};
    LOG(String(isLanding ? "landing  " : "takeoff  ") + stageNames[stage] + " jump=" + _jumpId +
        (stage == EVENT_STAGE_RETRACTED ? String("") : String(" t=") + usToMs(timeUs) + " ms"));
  }

  void takeoff(const Transition& t) {
    const bool finalizes = _inJump && _takeoff == PROVISIONAL && t.stage == STAGE_FINAL &&
                           (_landing == NONE || t.timeUs < _landingUs);
    if (finalizes) {
      _takeoff = FINAL;
      send(false, EVENT_STAGE_FINAL, t.timeUs, t.info);
      return;
    }
    if (!onBed()) {
      ignored(t.stage == STAGE_FINAL ? "takeoff final, but the takeoff is already final"
                                     : "takeoff provisional while already airborne");
      return;
    }
    _jumpId++;
    _inJump = true;
    _takeoff = t.stage == STAGE_FINAL ? FINAL : PROVISIONAL;
    _landing = NONE;
    send(false, t.stage == STAGE_FINAL ? EVENT_STAGE_FINAL : EVENT_STAGE_PROVISIONAL, t.timeUs,
         t.info);
  }

  void landing(const Transition& t) {
    if (!_inJump) {
      ignored("landing with no takeoff (before the first takeoff, or after a retracted one)");
      return;
    }
    if (_landing == FINAL || (_landing == PROVISIONAL && t.stage == STAGE_PROVISIONAL)) {
      ignored("landing already reported for this jump");
      return;
    }
    _landing = t.stage == STAGE_FINAL ? FINAL : PROVISIONAL;
    _landingUs = t.timeUs;
    send(true, t.stage == STAGE_FINAL ? EVENT_STAGE_FINAL : EVENT_STAGE_PROVISIONAL, t.timeUs,
         t.info);
  }

  void retractTakeoff() {
    if (!_inJump || _takeoff != PROVISIONAL || _landing != NONE) {
      ignored("retractTakeoff: no provisional takeoff without landing to retract");
      return;
    }
    _inJump = false;
    _takeoff = NONE;
    send(false, EVENT_STAGE_RETRACTED, 0, EventInfo());
  }

  void retractLanding() {
    if (!_inJump || _landing != PROVISIONAL) {
      ignored("retractLanding: no provisional landing to retract");
      return;
    }
    _landing = NONE;
    send(true, EVENT_STAGE_RETRACTED, 0, EventInfo());
  }
};
