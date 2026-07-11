#ifndef SERVER_LBG_LBGZONEBRIDGEJSONEXPORT_H_
#define SERVER_LBG_LBGZONEBRIDGEJSONEXPORT_H_

#include "server/lbg/LbgZoneBridge.h"

namespace lbg {
namespace zonebridge {

void publishZoneBridgeJson(const ZoneDelta& delta);

}  // namespace zonebridge
}  // namespace lbg

#endif  // SERVER_LBG_LBGZONEBRIDGEJSONEXPORT_H_
