/*
 * Client → serveur : position / marche joueur (opcode ObjController 0x71).
 */
#ifndef CLIENT_DATATRANSFORM_H_
#define CLIENT_DATATRANSFORM_H_

#include "server/zone/packets/object/ObjectControllerMessage.h"

class ClientDataTransform : public ObjectControllerMessage {
public:
	ClientDataTransform(uint64 objectId, uint32 timeStamp, uint32 moveCount, float dirX, float dirY, float dirZ, float dirW, float posX, float posZ, float posY, float speed)
		: ObjectControllerMessage(objectId, 0x1B, 0x71) {
		insertInt(timeStamp);
		insertInt(moveCount);
		insertFloat(dirX);
		insertFloat(dirY);
		insertFloat(dirZ);
		insertFloat(dirW);
		insertFloat(posX);
		insertFloat(posZ);
		insertFloat(posY);
		insertFloat(speed);
	}
};

#endif /* CLIENT_DATATRANSFORM_H_ */
