/*
 * Etat de position + envoi DataTransform pour core3client (bots Lia/Nix).
 */
#ifndef PLAYERLOCOMOTION_H_
#define PLAYERLOCOMOTION_H_

#include "system/lang.h"
#include "engine/util/u3d/Vector3.h"
#include "engine/util/u3d/Quaternion.h"

class Zone;
class ZoneClient;

class PlayerLocomotion {
	bool hasPosition;
	uint64 characterOid;
	uint64 parentId;
	Vector3 position;
	Quaternion direction;
	uint32 moveCount;
	uint32 lastTimeStamp;
	float runSpeed;

	bool hasGoal;
	float goalX;
	float goalY;
	float goalZ;
	float stopRadiusM;

public:
	PlayerLocomotion();

	void reset(uint64 oid);
	void setInitialPosition(float x, float z, float y, uint64 parent);
	void applyServerTransform(float x, float z, float y, float dirX, float dirY, float dirZ, float dirW, float speed);

	void setGoal(float x, float y, float z, float stopRadiusM);
	void clearGoal();

	void syncPosition(float x, float z, float y);

	bool hasActiveGoal() const;
	bool isReady() const;

	void tick(Zone* zone);

private:
	void sendTransform(ZoneClient* client, float speed);
	static float dist2d(float x1, float y1, float x2, float y2);
	void faceToward(float tx, float ty);
};

#endif /* PLAYERLOCOMOTION_H_ */
