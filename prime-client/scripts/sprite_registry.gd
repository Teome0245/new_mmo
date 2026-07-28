# sprite_registry.gd — résout kind/name/rôle → texture + teinte joueur
extends RefCounted
class_name SpriteRegistry

const MANIFEST_PATH := "res://config/sprite_manifest.json"

static var _manifest: Dictionary = {}
static var _loaded := false
static var _last_sprite_key: String = ""

static func last_sprite_key() -> String:
	return _last_sprite_key

static func resolve_texture(kind: String, entity_name: String = "", entity_key: String = "") -> Texture2D:
	_ensure_loaded()
	var role := _resolve_role(entity_key, entity_name)
	var key := _resolve_sprite_key(kind, entity_name, role)
	_last_sprite_key = key
	if key == "":
		return null
	var sprites: Dictionary = _manifest.get("sprites", {})
	var path := str(sprites.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		if kind == "player":
			for fallback_key in ["player_human", "player_bot"]:
				var fb := str(sprites.get(fallback_key, ""))
				if fb != "" and ResourceLoader.exists(fb):
					path = fb
					break
		if path == "" or not ResourceLoader.exists(path):
			return null
	return load(path) as Texture2D

static func resolve_tint(kind: String, entity_name: String = "") -> Color:
	_ensure_loaded()
	if kind != "player":
		return Color.WHITE
	var tints: Dictionary = _manifest.get("player_tints", {})
	var strength := float(_manifest.get("tint_strength", 0.35))
	var name_l := entity_name.to_lower().strip_edges()
	if name_l == "":
		return Color.WHITE
	for key in tints.keys():
		if name_l == str(key).to_lower() or name_l.contains(str(key).to_lower()):
			var c := Color(str(tints[key]))
			return Color.WHITE.lerp(c, clampf(strength, 0.0, 1.0))
	return Color.WHITE

static func display_px() -> float:
	_ensure_loaded()
	var override := float(_manifest.get("display_px", 0.0))
	if override > 0.0:
		return override
	return Projection3D2D.entity_token_px()

static func resolve_scale_multiplier(sprite_key: String) -> float:
	_ensure_loaded()
	var scales: Dictionary = _manifest.get("sprite_scales", {})
	return float(scales.get(sprite_key, 1.0))

static func _resolve_role(entity_key: String, entity_name: String) -> String:
	if entity_key == "" and entity_name == "":
		return ""
	var anchor := NpcAnchorResolver.resolve(entity_key, entity_name)
	return str(anchor.get("role", ""))

static func _resolve_sprite_key(kind: String, entity_name: String, role: String) -> String:
	var rules: Array = _manifest.get("rules", [])
	var name_l := entity_name.to_lower().strip_edges()
	var role_l := role.to_lower().strip_edges()
	for rule_v in rules:
		if not rule_v is Dictionary:
			continue
		var rule: Dictionary = rule_v
		if str(rule.get("kind", "")) != kind:
			continue
		var roles: Variant = rule.get("role_match", [])
		if roles is Array and not (roles as Array).is_empty():
			var role_hit := false
			if role_l != "":
				for rv in roles as Array:
					if role_l == str(rv).to_lower():
						role_hit = true
						break
			if not role_hit:
				continue
		var exact := str(rule.get("name_exact", "")).strip_edges().to_lower()
		if exact != "":
			if name_l != exact and not name_l.contains(exact):
				continue
			return str(rule.get("sprite", ""))
		var matches: Variant = rule.get("name_match", [])
		if matches is Array and not (matches as Array).is_empty():
			var hit := false
			for frag_v in matches:
				if name_l.contains(str(frag_v).to_lower()):
					hit = true
					break
			if not hit:
				continue
		return str(rule.get("sprite", ""))
	return ""

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("SpriteRegistry: manifest absent %s" % MANIFEST_PATH)
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		_manifest = raw
