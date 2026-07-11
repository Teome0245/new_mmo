// LbgZoneBridgeTickTask.h — tâche périodique ZB-0 (≈20 Hz)

#ifndef SERVER_LBG_LBGZONEBRIDGETICKTASK_H_
#define SERVER_LBG_LBGZONEBRIDGETICKTASK_H_

#include "engine/engine.h"
#include "server/lbg/LbgZoneBridge.h"
#include "server/zone/Zone.h"
#include "server/zone/ZoneServer.h"

class LbgZoneBridgeTickTask : public Task {
    ManagedReference<ZoneServer*> zone_server_;
    int interval_ms_;

public:
    LbgZoneBridgeTickTask(ZoneServer* zone_server, int interval_ms)
        : interval_ms_(interval_ms) {
        zone_server_ = zone_server;
    }

    void run() {
        lbg::zonebridge::LbgZoneBridge* bridge = lbg::zonebridge::lbgZoneBridgeInstance();
        if (bridge == nullptr || !bridge->enabled() || zone_server_ == nullptr) {
            schedule(interval_ms_);
            return;
        }

        const int count = zone_server_->getZoneCount();
        for (int i = 0; i < count; ++i) {
            ManagedReference<Zone*> zone = zone_server_->getZone(i);
            if (zone == nullptr) {
                continue;
            }
            const String zone_name = zone->getZoneName();
            bridge->onZoneTick(std::string(zone_name.toCharArray()));
        }

        schedule(interval_ms_);
    }
};

#endif  // SERVER_LBG_LBGZONEBRIDGETICKTASK_H_
