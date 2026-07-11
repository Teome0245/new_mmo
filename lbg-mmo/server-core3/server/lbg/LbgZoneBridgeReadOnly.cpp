// LbgZoneBridgeReadOnly.cpp — ZB-0 impl lecture seule (tick + delta vide)

#include "server/lbg/LbgZoneBridge.h"

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
    mutable std::mutex zone_mu_;

public:
    void onZoneTick(const std::string& zone_name) override {
        tick_.fetch_add(1, std::memory_order_relaxed);
        std::lock_guard<std::mutex> lock(zone_mu_);
        last_zone_ = zone_name;
    }

    ZoneDelta collectReadOnlyDelta() const override {
        ZoneDelta delta;
        delta.tick = tick_.load(std::memory_order_relaxed);
        std::lock_guard<std::mutex> lock(zone_mu_);
        delta.zone_name = last_zone_;
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

}  // namespace zonebridge
}  // namespace lbg
