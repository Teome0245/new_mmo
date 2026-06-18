/*
 * File ia_bridge/bot_move.jsonl — commandes de marche pour core3client.
 */
#ifndef BOTMOVEQUEUE_H_
#define BOTMOVEQUEUE_H_

#include "system/lang.h"

struct BotMoveCommand {
	bool valid;
	String verb;
	float x;
	float y;
	float z;
	float stopRadiusM;
};

class BotMoveQueue {
	String queuePath;
	String characterFilter;

public:
	BotMoveQueue(const String& path, const String& characterName);

	BotMoveCommand poll();
};

#endif /* BOTMOVEQUEUE_H_ */
