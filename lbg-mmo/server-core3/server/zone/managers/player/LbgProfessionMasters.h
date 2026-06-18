/*
 * Profession master boxes granted via Character Builder (LBG admin tooling).
 */

#ifndef LBGPROFESSIONMASTERS_H_
#define LBGPROFESSIONMASTERS_H_

namespace server {
namespace zone {
namespace managers {
namespace player {

static const char* const LBG_PROFESSION_MASTER_SKILLS[] = {
	"crafting_architect_master",
	"crafting_armorsmith_master",
	"crafting_artisan_master",
	"outdoors_bio_engineer_master",
	"combat_bountyhunter_master",
	"combat_brawler_master",
	"combat_carbine_master",
	"crafting_chef_master",
	"science_combatmedic_master",
	"combat_commando_master",
	"outdoors_creaturehandler_master",
	"social_dancer_master",
	"science_doctor_master",
	"crafting_droidengineer_master",
	"social_entertainer_master",
	"combat_1hsword_master",
	"social_imagedesigner_master",
	"combat_marksman_master",
	"science_medic_master",
	"crafting_merchant_master",
	"social_musician_master",
	"combat_polearm_master",
	"pilot_rebel_navy_master",
	"pilot_imperial_navy_master",
	"pilot_neutral_master",
	"combat_pistol_master",
	"social_politician_master",
	"outdoors_ranger_master",
	"combat_rifleman_master",
	"outdoors_scout_master",
	"crafting_shipwright_master",
	"combat_smuggler_master",
	"outdoors_squadleader_master",
	"combat_2hsword_master",
	"crafting_tailor_master",
	"combat_unarmed_master",
	"crafting_weaponsmith_master",
};

static const int LBG_PROFESSION_MASTER_SKILL_COUNT =
	sizeof(LBG_PROFESSION_MASTER_SKILLS) / sizeof(LBG_PROFESSION_MASTER_SKILLS[0]);

} // namespace player
} // namespace managers
} // namespace zone
} // namespace server

#endif // LBGPROFESSIONMASTERS_H_
