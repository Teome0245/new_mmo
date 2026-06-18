/*
 * LBG admin account helpers (ADR 0006) — skill pool + permanent attributes for admin_level >= 4.
 */

#ifndef LBGADMINACCOUNT_H_
#define LBGADMINACCOUNT_H_

#include "server/zone/managers/player/LbgAdminLevels.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/login/account/AccountManager.h"
#include "server/zone/ZoneClientSession.h"

namespace server {
namespace zone {
namespace managers {
namespace player {

static const int LBG_DEFAULT_SKILL_POINT_BASE = 250;
/** Marge au-dessus du total requis pour tous les métiers au max (~2702). */
static const int LBG_ADMIN_SKILL_POINT_BASE = 3000;
static const int LBG_ADMIN_ATTRIBUTE_BASELINE = 1500;
static const int LBG_ADMIN_ATTRIBUTE_FLOOR = 100;

inline unsigned int getEffectiveAdminLevel(PlayerObject* ghost, ZoneClientSession* client = nullptr) {
	unsigned int level = ghost != nullptr ? ghost->getAdminLevel() : 0;
	ManagedReference<Account*> account = nullptr;

	if (ghost != nullptr) {
		account = ghost->getAccount();

		if (account == nullptr && ghost->getAccountID() != 0) {
			account = AccountManager::getAccount(ghost->getAccountID(), false);
		}
	}

	if (account == nullptr && client != nullptr && client->getAccountID() != 0) {
		account = AccountManager::getAccount(client->getAccountID(), false);
	}

	if (account != nullptr && account->getAdminLevel() > level) {
		level = account->getAdminLevel();
	}

	return level;
}

inline int getAdminSkillPointBase(unsigned int effectiveAdminLevel) {
	return effectiveAdminLevel >= LBG_ADMIN_LEVEL_ADMIN ? LBG_ADMIN_SKILL_POINT_BASE : LBG_DEFAULT_SKILL_POINT_BASE;
}

inline int getAdminAttributeTarget(int currentBase) {
	int value = currentBase;

	if (value < LBG_ADMIN_ATTRIBUTE_FLOOR)
		value = LBG_ADMIN_ATTRIBUTE_FLOOR;

	if (value < LBG_ADMIN_ATTRIBUTE_BASELINE)
		value = LBG_ADMIN_ATTRIBUTE_BASELINE;

	return value;
}

inline void applyAdminPermanentAttributes(CreatureObject* player) {
	if (player == nullptr)
		return;

	bool changed = false;

	for (int i = 0; i < 9; ++i) {
		int targetBase = getAdminAttributeTarget(player->getBaseHAM(i));

		if (targetBase != player->getBaseHAM(i)) {
			player->setBaseHAM(i, targetBase, false);
			changed = true;
		}

		if (player->getMaxHAM(i) < targetBase)
			player->setMaxHAM(i, targetBase, false);

		if (player->getHAM(i) < targetBase)
			player->setHAM(i, targetBase, false);
	}

	if (changed && player->isPlayerCreature())
		player->sendSystemMessage("Admin attributes applied.");
}

} // namespace player
} // namespace managers
} // namespace zone
} // namespace server

#endif // LBGADMINACCOUNT_H_
