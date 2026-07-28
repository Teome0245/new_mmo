# ui_icon_registry.gd — Icônes flat HUD (SVG sous assets/ui/icons)
class_name UiIconRegistry

const ICONS_DIR := "res://assets/ui/icons/"

static var _cache: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if name == "":
		name = "empty"
	if _cache.has(name):
		return _cache[name]
	var path := ICONS_DIR + name + ".svg"
	if not ResourceLoader.exists(path):
		path = ICONS_DIR + "empty.svg"
	var t: Texture2D = load(path) as Texture2D
	_cache[name] = t
	return t

static func hotbar_icon(index: int) -> String:
	var keys := ["atk", "skill", "item", "emote", "map", "tal", "inv", "chat", "mount", "menu"]
	if index < 0 or index >= keys.size():
		return "empty"
	return keys[index]

static func item_icon(item_name: String) -> String:
	match item_name.to_lower():
		"caisse":
			return "crate"
		"ration":
			return "ration"
		"kit":
			return "kit"
		"cuivre":
			return "copper"
		"vis":
			return "screw"
		"badge":
			return "badge"
		"carte":
			return "card"
	return "empty"
