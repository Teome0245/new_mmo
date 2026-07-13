// LbgZoneBridgeCollect.h — ZB-0/1 collecte entités depuis ZoneServer

#ifndef LBG_ZONE_BRIDGE_COLLECT_H_
#define LBG_ZONE_BRIDGE_COLLECT_H_

#include "server/lbg/LbgZoneBridge.h"
#include "server/zone/ZoneServer.h"

namespace lbg {
namespace zonebridge {

ZoneDelta collectZoneDeltaFromServer(ZoneServer* zone_server, uint64_t tick, const std::string& zone_name);

}  // namespace zonebridge
}  // namespace lbg

#endif  // LBG_ZONE_BRIDGE_COLLECT_H_
