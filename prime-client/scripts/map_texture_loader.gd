# map_texture_loader.gd — résout la texture planète depuis tatooine_map_config.json
extends RefCounted
class_name MapTextureLoader

const CONFIG_PATH := "res://assets/maps/tatooine_map_config.json"
const MAP_DIR := "res://assets/maps/"

static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return raw if raw is Dictionary else {}

## usage: "world" (vue jeu) ou "planet_map" (Ctrl+M)
static func resolve_path(usage: String = "world") -> String:
	var cfg := load_config()
	var key := "planet_map_texture" if usage == "planet_map" else "world_texture"
	var explicit := str(cfg.get(key, "")).strip_edges()
	if explicit != "" and ResourceLoader.exists(explicit):
		return explicit
	var planet := str(cfg.get("planet", "tatooine"))
	var exts: PackedStringArray = PackedStringArray(["webp", "png", "jpg", "jpeg", "svg"])
	for ext in exts:
		var p := MAP_DIR + planet + "_satellite." + ext
		if ResourceLoader.exists(p):
			return p
	for ext in exts:
		var p := MAP_DIR + planet + "." + ext
		if ResourceLoader.exists(p):
			return p
	var legacy := str(cfg.get("texture", ""))
	if legacy != "" and ResourceLoader.exists(legacy):
		return legacy
	return ""

static func world_render_cfg() -> Dictionary:
	var cfg := load_config()
	var wr: Variant = cfg.get("world_render", null)
	return wr if wr is Dictionary else {}

static func position_map_city() -> String:
	return str(world_render_cfg().get("position_map_city", "")).strip_edges()

static func show_planet_texture() -> bool:
	return bool(world_render_cfg().get("show_planet_texture", false))

static func use_procedural_backdrop() -> bool:
	var wr := world_render_cfg()
	if wr.is_empty():
		return true
	return str(wr.get("backdrop", "procedural_canyon")) != "none"

static func entity_marker_style() -> String:
	return str(world_render_cfg().get("entity_markers", "triangle")).strip_edges()

static func load_texture(usage: String = "world") -> Texture2D:
	var path := resolve_path(usage)
	if path == "":
		return null
	return load(path) as Texture2D
