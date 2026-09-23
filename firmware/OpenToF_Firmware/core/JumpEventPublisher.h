// Turns transitions (takeoff/landing) into BLE events (contact time / flight time).
#pragma once

#include <stdint.h>

#include "BleService.h"
#include "Logging.h"
#include "Transition.h"

static uint32_t usToMs(uint64_t us) { return (uint32_t)((us + 500) / 1000); }

class JumpEventPublisher {
 public:
  // Every transition the algorithm reports is logged, including the ones the firmware ignores
  // (duplicate takeoff, landing with no prior takeoff) -- if your algorithm's state machine gets
  // confused, this is where it shows up, even though no BLE event is sent for those.
  void handle(const Transition& t) {
    if (t.type == TRANSITION_TAKEOFF) {
      if (_airborne) {
        LOG("takeoff ignored: already airborne (algorithm reported takeoff twice with no landing)");
        return;
      }
      if (_haveLanding) {
        const uint32_t contactMs = usToMs(t.timeUs - _lastLandingUs);
        bleNotifyTakeoff(contactMs);
        LOG(String("takeoff  contact=") + contactMs + " ms");
      } else {
        LOG("takeoff (first after boot: no BLE event, no previous landing for a contact time)");
      }
      _lastTakeoffUs = t.timeUs;
      _airborne = true;
    } else {
      if (!_airborne) {
        LOG("landing ignored: no takeoff seen yet (algorithm reported landing before any takeoff)");
        return;
      }
      const uint32_t flightMs = usToMs(t.timeUs - _lastTakeoffUs);
      bleNotifyLanding(flightMs);
      LOG(String("landing  flight=") + flightMs + " ms");
      _lastLandingUs = t.timeUs;
      _haveLanding = true;
      _airborne = false;
    }
  }

 private:
  uint64_t _lastTakeoffUs = 0;
  uint64_t _lastLandingUs = 0;
  bool _airborne = false;
  bool _haveLanding = false;
};
