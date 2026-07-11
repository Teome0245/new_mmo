// LbgZoneBridge.h — ZB-0 lecture seule (Core3 Prime ↔ lbg_gateway lbg-ws/2)
// Spec : LBG_IA_MMO/docs/core3_zone_bridge_spec.md

#ifndef LBG_ZONE_BRIDGE_H_
#define LBG_ZONE_BRIDGE_H_

#include <cstdint>
#include <string>
#include <vector>

namespace lbg {
namespace zonebridge {

struct ZoneEntitySnapshot {
    uint64_t object_id = 0;
    std::string name;
    float x = 0.f;
    float y = 0.f;
    float z = 0.f;
    int cell_id = 0;
    std::string kind;  // player | npc
};

struct ZoneDelta {
    std::string zone_name;
    uint64_t tick = 0;
    std::vector<ZoneEntitySnapshot> entities;
    std::vector<uint64_t> removed_ids;
};

// Interface ZB-0 : hook read-only depuis ZoneServer::update (implémentation future ZB-1)
class LbgZoneBridge {
public:
    virtual ~LbgZoneBridge() = default;

    virtual void onZoneTick(const std::string& zone_name) = 0;
    virtual ZoneDelta collectReadOnlyDelta() const = 0;
    virtual bool enabled() const = 0;
};

LbgZoneBridge* lbgZoneBridgeInstance();
void setLbgZoneBridge(LbgZoneBridge* bridge);

}  // namespace zonebridge
}  // namespace lbg

#endif  // LBG_ZONE_BRIDGE_H_
