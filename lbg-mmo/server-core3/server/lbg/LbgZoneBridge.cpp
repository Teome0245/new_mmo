// LbgZoneBridge.cpp — registre singleton ZoneBridge

#include "server/lbg/LbgZoneBridge.h"

namespace lbg {
namespace zonebridge {

namespace {

class NullZoneBridge : public LbgZoneBridge {
public:
    void onZoneTick(const std::string&) override {}
    ZoneDelta collectReadOnlyDelta() const override { return {}; }
    bool enabled() const override { return false; }
};

NullZoneBridge g_null_bridge;
LbgZoneBridge* g_active = &g_null_bridge;

}  // namespace

LbgZoneBridge* lbgZoneBridgeInstance() {
    return g_active;
}

void setLbgZoneBridge(LbgZoneBridge* bridge) {
    g_active = bridge ? bridge : &g_null_bridge;
}

}  // namespace zonebridge
}  // namespace lbg
