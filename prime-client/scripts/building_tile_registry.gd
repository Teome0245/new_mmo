# building_tile_registry.gd — kind bâtiment → tuile SVG top-down
class_name BuildingTileRegistry

const TILES := {
	"bank": "res://assets/world/buildings/tile_bank.svg",
	"cantina": "res://assets/world/buildings/tile_cantina.svg",
	"inn": "res://assets/world/buildings/tile_inn.svg",
	"shops": "res://assets/world/buildings/tile_market.svg",
	"market": "res://assets/world/buildings/tile_market.svg",
	"starport_shuttle": "res://assets/world/buildings/tile_starport.svg",
	"clinic": "res://assets/world/buildings/tile_clinic.svg",
	"mission_terminal": "res://assets/world/buildings/tile_terminal.svg",
	"terminal": "res://assets/world/buildings/tile_terminal.svg",
	"town_hall": "res://assets/world/buildings/tile_town_hall.svg",
	"city_gate": "res://assets/world/buildings/tile_gate.svg",
	"trainers_combat": "res://assets/world/buildings/tile_training.svg",
	"trainer_artisan": "res://assets/world/buildings/tile_training.svg",
	"npc_housing_block": "res://assets/world/buildings/tile_housing.svg",
}

static var _cache: Dictionary = {}

static func texture_for_kind(kind: String) -> Texture2D:
	var path := str(TILES.get(kind, TILES.get("shops", "")))
	if path == "":
		path = "res://assets/world/buildings/tile_generic.svg"
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex:
		_cache[path] = tex
	return tex
