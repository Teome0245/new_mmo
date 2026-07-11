// LbgZoneBridgeInit.cpp — enregistrement ZB-0 au démarrage ZoneServer

#include "server/lbg/LbgZoneBridgeInit.h"
#include "server/lbg/LbgZoneBridgeTickTask.h"

#include "system/lang/ref/Reference.h"

#include <cstdlib>
#include <string>

namespace lbg {
namespace zonebridge {

namespace {

int tickIntervalMs() {
    const char* raw = std::getenv("LBG_ZONE_BRIDGE_TICK_MS");
    if (raw == nullptr) {
        return 50;
    }
    int v = 50;
    try {
        v = std::stoi(raw);
    } catch (...) {
        v = 50;
    }
    if (v < 20) {
        v = 20;
    }
    if (v > 5000) {
        v = 5000;
    }
    return v;
}

}  // namespace

void startZoneBridgeTick(ZoneServer* zone_server) {
    ensureReadOnlyZoneBridge();
    LbgZoneBridge* bridge = lbgZoneBridgeInstance();
    if (bridge == nullptr || !bridge->enabled() || zone_server == nullptr) {
        return;
    }

    Reference<LbgZoneBridgeTickTask*> task = new LbgZoneBridgeTickTask(zone_server, tickIntervalMs());
    task->schedule(tickIntervalMs());
}

}  // namespace zonebridge
}  // namespace lbg
