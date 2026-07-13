#ifndef SERVER_LBG_LBGZONEBRIDGEINIT_H_
#define SERVER_LBG_LBGZONEBRIDGEINIT_H_

#include "server/zone/ZoneServer.h"

namespace lbg {
namespace zonebridge {

void ensureReadOnlyZoneBridge();
void bindReadOnlyZoneBridgeServer(ZoneServer* zone_server);
void startZoneBridgeTick(ZoneServer* zone_server);

}  // namespace zonebridge
}  // namespace lbg

#endif  // SERVER_LBG_LBGZONEBRIDGEINIT_H_
