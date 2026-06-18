generic_npc = Creature:new {
	objectName = "npc_name",
	randomNameType = NAME_GENERIC,
	randomNameTag = true,
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	chanceHit = 0.5,
	damageMin = 10,
	damageMax = 11,
	baseXp = 10,
	baseHAM = 100,
	baseHAMmax = 100,
	armor = 0,
	resists = {0,0,0,0,0,0,0,0,-1},
	meatType = "",
	meatAmount = 0,
	hideType = "",
	hideAmount = 0,
	boneType = "",
	boneAmount = 0,
	milk = 0,
	tamingChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = 0,
	diet = HERBIVORE,

	templates = {"object/mobile/shared_human_male.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "",
	attacks = {}
}

if CreatureTemplates ~= nil then
	CreatureTemplates:addCreatureTemplate(generic_npc, "generic_npc")
end
