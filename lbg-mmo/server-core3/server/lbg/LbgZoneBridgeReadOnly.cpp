// LbgZoneBridgeReadOnly.cpp — ZB-0/1 impl lecture seule (tick + collecte entités)

#include "server/lbg/LbgZoneBridge.h"
#include "server/lbg/LbgZoneBridgeCollect.h"

#include "server/zone/ZoneServer.h"

#include <atomic>
#include <cstdlib>
#include <mutex>

namespace lbg {
namespace zonebridge {

namespace {

bool bridgeEnabledFromEnv() {
    const char* raw = std::getenv("LBG_ZONE_BRIDGE_ENABLED");
    if (raw == nullptr) {
        return true;  // ZB-0 actif une fois le hook installé
    }
    return raw[0] == '1' || raw[0] == 'y' || raw[0] == 'Y';
}

class ReadOnlyZoneBridge : public LbgZoneBridge {
    std::atomic<uint64_t> tick_{0};
    std::string last_zone_;
    ZoneServer* zone_server_{nullptr};
    mutable std::mutex zone_mu_;

public:
    void setZoneServer(ZoneServer* zone_server) {
        zone_server_ = zone_server;
    }

    void onZoneTick(const std::string& zone_name) override {
        tick_.fetch_add(1, std::memory_order_relaxed);
        std::lock_guard<std::mutex> lock(zone_mu_);
        last_zone_ = zone_name;
    }

    ZoneDelta collectReadOnlyDelta() const override {
        std::string zone_copy;
        const uint64_t tick = tick_.load(std::memory_order_relaxed);
        {
            std::lock_guard<std::mutex> lock(zone_mu_);
            zone_copy = last_zone_;
        }
        if (zone_server_ != nullptr) {
            return collectZoneDeltaFromServer(zone_server_, tick, zone_copy);
        }
        ZoneDelta delta;
        delta.tick = tick;
        delta.zone_name = zone_copy;
        return delta;
    }

    bool enabled() const override {
        return bridgeEnabledFromEnv();
    }
};

ReadOnlyZoneBridge g_readonly_bridge;

}  // namespace

void ensureReadOnlyZoneBridge() {
    setLbgZoneBridge(&g_readonly_bridge);
}

void bindReadOnlyZoneBridgeServer(ZoneServer* zone_server) {
    g_readonly_bridge.setZoneServer(zone_server);
}

}  // namespace zonebridge
}  // namespace lbg
