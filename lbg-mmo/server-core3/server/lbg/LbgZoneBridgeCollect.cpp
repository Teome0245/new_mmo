// LbgZoneBridgeCollect.cpp — joueurs en ligne + PNJ proches (ZB-1)

#include "server/lbg/LbgZoneBridgeCollect.h"

#include "server/zone/InRangeObjectsVector.h"
#include "server/zone/Zone.h"
#include "server/zone/ZoneServer.h"
#include "server/zone/managers/player/PlayerManager.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/scene/SceneObject.h"

namespace lbg {
namespace zonebridge {

namespace {

constexpr int kMaxEntities = 64;
constexpr float kNpcScanRange = 96.f;

void appendPlayer(CreatureObject* player, ZoneDelta& delta) {
    if (player == nullptr) {
        return;
    }
    ZoneEntitySnapshot ent;
    ent.object_id = player->getObjectID();
    ent.name = std::string(player->getFirstName().toCharArray());
    ent.x = player->getWorldPositionX();
    ent.y = player->getWorldPositionY();
    ent.z = player->getWorldPositionZ();
    ent.kind = "player";
    delta.entities.push_back(ent);
}

void appendNpc(CreatureObject* npc, ZoneDelta& delta) {
    if (npc == nullptr) {
        return;
    }
    ZoneEntitySnapshot ent;
    ent.object_id = npc->getObjectID();
    const char* custom = npc->getCustomObjectName().toCharArray();
    if (custom != nullptr && custom[0] != '\0') {
        ent.name = std::string(custom);
    } else {
        ent.name = std::string(npc->getDisplayedName().toCharArray());
    }
    ent.x = npc->getWorldPositionX();
    ent.y = npc->getWorldPositionY();
    ent.z = npc->getWorldPositionZ();
    ent.kind = "npc";
    delta.entities.push_back(ent);
}

}  // namespace

ZoneDelta collectZoneDeltaFromServer(ZoneServer* zone_server, uint64_t tick, const std::string& zone_name) {
    ZoneDelta delta;
    delta.tick = tick;
    delta.zone_name = zone_name;

    if (zone_server == nullptr) {
        return delta;
    }

    PlayerManager* player_manager = zone_server->getPlayerManager();
    if (player_manager == nullptr) {
        return delta;
    }

    const Vector<uint64> online = player_manager->getOnlinePlayerList();
    CreatureObject* anchor_player = nullptr;

    for (int i = 0; i < online.size() && static_cast<int>(delta.entities.size()) < kMaxEntities; ++i) {
        ManagedReference<SceneObject*> obj = zone_server->getObject(online.get(i), true);
        if (obj == nullptr || !obj->isPlayerCreature()) {
            continue;
        }
        CreatureObject* player = obj->asCreatureObject();
        appendPlayer(player, delta);
        if (anchor_player == nullptr) {
            anchor_player = player;
            Zone* zone = player->getZone();
            if (zone != nullptr) {
                delta.zone_name = std::string(zone->getZoneName().toCharArray());
            }
        }
    }

    if (anchor_player == nullptr || static_cast<int>(delta.entities.size()) >= kMaxEntities) {
        return delta;
    }

    Zone* zone = anchor_player->getZone();
    if (zone == nullptr) {
        return delta;
    }

    InRangeObjectsVector in_range;
    zone->getInRangeObjects(
        anchor_player->getWorldPositionX(),
        anchor_player->getWorldPositionZ(),
        anchor_player->getWorldPositionY(),
        kNpcScanRange,
        &in_range,
        true,
        false);

    for (int i = 0; i < in_range.size() && static_cast<int>(delta.entities.size()) < kMaxEntities; ++i) {
        SceneObject* scene = static_cast<SceneObject*>(in_range.get(i));
        if (scene == nullptr || !scene->isCreatureObject()) {
            continue;
        }
        CreatureObject* creo = scene->asCreatureObject();
        if (creo == nullptr || creo->isPlayerCreature()) {
            continue;
        }
        appendNpc(creo, delta);
    }

    return delta;
}

}  // namespace zonebridge
}  // namespace lbg
