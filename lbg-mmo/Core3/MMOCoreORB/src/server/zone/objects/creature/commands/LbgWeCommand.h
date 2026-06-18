#ifndef LBGWECOMMAND_H_
#define LBGWECOMMAND_H_

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/commands/QueueCommand.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/login/account/Account.h"

#include <cstdio>

class LbgWeCommand : public QueueCommand {
public:
	LbgWeCommand(const String& name, ZoneProcessServer* server)
		: QueueCommand(name, server) {
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {
		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		if (!creature->isPlayerCreature())
			return GENERALERROR;

		ManagedReference<PlayerObject*> ghost = creature->getPlayerObject();
		if (ghost == nullptr) {
			creature->sendSystemMessage("World Editor: acces Dev+ requis (admin >= 3).");
			return GENERALERROR;
		}

		int effectiveAdmin = ghost->getAdminLevel();
		ManagedReference<Account*> account = ghost->getAccount();
		if (account != nullptr && effectiveAdmin < 3 && account->getAdminLevel() >= 3) {
			effectiveAdmin = account->getAdminLevel();
		}

		if (effectiveAdmin < 3) {
			creature->sendSystemMessage("World Editor: acces Dev+ requis (admin >= 3).");
			return GENERALERROR;
		}

		String line = arguments.toString().trim();
		if (line.isEmpty()) {
			creature->sendSystemMessage("Usage: /lbgwe session on|off | dump | status | npc place <id> | export");
			return INVALIDPARAMETERS;
		}

		FILE* queue = fopen("ia_bridge/world_editor_cmd.queue", "a");
		if (queue == nullptr) {
			creature->sendSystemMessage("World Editor: impossible d ouvrir la file de commandes.");
			return GENERALERROR;
		}

		fprintf(queue, "%llu|%s|%s\n",
				(unsigned long long) creature->getObjectID(),
				creature->getFirstName().toCharArray(),
				line.toCharArray());
		fclose(queue);

		creature->sendSystemMessage("[WorldEditor] commande recue: " + line);
		return SUCCESS;
	}
};

#endif // LBGWECOMMAND_H_
