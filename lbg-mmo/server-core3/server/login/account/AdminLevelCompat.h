/*
 * LBG admin levels (ADR 0006) — map legacy SWGEmu account levels to 0–4.
 */

#ifndef ADMINLEVELCOMPAT_H_
#define ADMINLEVELCOMPAT_H_

#include "system/platform.h"

namespace server {
namespace login {
namespace account {

/** Normalize DB / legacy admin_level to LBG scale 0–4. Idempotent for 0–4. */
inline int normalizeAdminLevelFromLegacy(int raw) {
	if (raw >= 0 && raw <= 4)
		return raw;

	switch (raw) {
	case 1:
	case 2:
	case 3:
	case 6:
		return 1; // gm
	case 7:
	case 8:
	case 9:
	case 10:
	case 11:
	case 12:
		return 2; // moderator
	case 13:
	case 14:
		return 3; // dev
	default:
		if (raw >= 15)
			return 4; // admin
		return 0;
	}
}

} // namespace account
} // namespace login
} // namespace server

#endif // ADMINLEVELCOMPAT_H_
