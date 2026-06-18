/*
 * LBG admin scale (ADR 0006). Shared by zone + login (AdminLevelCompat).
 */

#ifndef LBGADMINLEVELS_H_
#define LBGADMINLEVELS_H_

namespace server {
namespace zone {
namespace managers {
namespace player {

/** LBG permission scale 0–4 (see staff/levels/lbg_*.lua). */
static const int LBG_ADMIN_LEVEL_PLAYER = 0;
static const int LBG_ADMIN_LEVEL_GM = 1;
static const int LBG_ADMIN_LEVEL_MODERATOR = 2;
static const int LBG_ADMIN_LEVEL_DEV = 3;
static const int LBG_ADMIN_LEVEL_ADMIN = 4;

} // namespace player
} // namespace managers
} // namespace zone
} // namespace server

#endif // LBGADMINLEVELS_H_
