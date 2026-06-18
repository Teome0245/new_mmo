/*
 * PlayerLocomotion.cpp
 */
#include "PlayerLocomotion.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "client/zone/packets/ClientDataTransform.h"
#include "engine/util/u3d/Quaternion.h"

PlayerLocomotion::PlayerLocomotion() {
	hasPosition = false;
	characterOid = 0;
	parentId = 0;
	moveCount = 0;
	lastTimeStamp = 0;
	runSpeed = 5.5f;
	hasGoal = false;
	goalX = goalY = goalZ = 0.f;
	stopRadiusM = 2.f;
	direction = Quaternion();
	position.set(0.f, 0.f, 0.f);
}

void PlayerLocomotion::reset(uint64 oid) {
	characterOid = oid;
	hasPosition = false;
	hasGoal = false;
	moveCount = 0;
}

void PlayerLocomotion::setInitialPosition(float x, float z, float y, uint64 parent) {
	position.set(x, z, y);
	parentId = parent;
	hasPosition = true;
}

void PlayerLocomotion::applyServerTransform(float x, float z, float y, float dirX, float dirY, float dirZ, float dirW, float speed) {
	position.set(x, z, y);
	direction.set(dirW, dirX, dirY, dirZ);
	if (speed >= 0.f) {
		runSpeed = speed > 0.01f ? speed : runSpeed;
	}
	hasPosition = true;
}

void PlayerLocomotion::setGoal(float x, float y, float z, float stopRadius) {
	goalX = x;
	goalY = y;
	goalZ = z;
	stopRadiusM = stopRadius > 0.1f ? stopRadius : 2.f;
	hasGoal = true;
}

void PlayerLocomotion::clearGoal() {
	hasGoal = false;
}

void PlayerLocomotion::syncPosition(float x, float z, float y) {
	position.set(x, z, y);
	hasPosition = true;
	clearGoal();
}

bool PlayerLocomotion::hasActiveGoal() const {
	return hasGoal;
}

bool PlayerLocomotion::isReady() const {
	return hasPosition && characterOid != 0;
}

float PlayerLocomotion::dist2d(float x1, float y1, float x2, float y2) {
	float dx = x1 - x2;
	float dy = y1 - y2;
	return sqrt(dx * dx + dy * dy);
}

void PlayerLocomotion::faceToward(float tx, float ty) {
	float dx = tx - position.getX();
	float dy = ty - position.getY();
	if (dx * dx + dy * dy < 0.0001f) {
		return;
	}
	float angle = atan2(dy, dx);
	direction.setHeadingDirection(angle);
}

void PlayerLocomotion::sendTransform(ZoneClient* client, float speed) {
	if (client == nullptr || characterOid == 0) {
		return;
	}
	uint32 now = System::getMiliTime();
	if (now <= lastTimeStamp) {
		now = lastTimeStamp + 200;
	}
	lastTimeStamp = now;
	++moveCount;

	auto* msg = new ClientDataTransform(
		characterOid,
		now,
		moveCount,
		direction.getX(),
		direction.getY(),
		direction.getZ(),
		direction.getW(),
		position.getX(),
		position.getZ(),
		position.getY(),
		speed);
	client->sendMessage(msg);
}

void PlayerLocomotion::tick(Zone* zone) {
	if (!hasGoal || !isReady() || zone == nullptr) {
		return;
	}

	ZoneClient* client = zone->getZoneClient();
	if (client == nullptr) {
		return;
	}

	float dist = dist2d(position.getX(), position.getY(), goalX, goalY);
	if (dist <= stopRadiusM) {
		clearGoal();
		sendTransform(client, 0.f);
		return;
	}

	faceToward(goalX, goalY);

	float step = runSpeed * 0.45f;
	if (step > dist - stopRadiusM) {
		step = dist - stopRadiusM;
	}
	if (step < 0.05f) {
		clearGoal();
		return;
	}

	float nx = position.getX() + (goalX - position.getX()) * (step / dist);
	float ny = position.getY() + (goalY - position.getY()) * (step / dist);
	position.set(nx, position.getZ(), ny);

	sendTransform(client, runSpeed);
}
