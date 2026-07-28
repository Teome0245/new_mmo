# portrait_registry.gd — résout kind/name/rôle/expression → texture portrait
extends RefCounted
class_name PortraitRegistry

const MANIFEST_PATH := "res://config/dialogue_portraits.json"

static var _manifest: Dictionary = {}
static var _loaded := false

static func resolve_texture(
	kind: String,
	entity_name: String = "",
	entity_key: String = "",
	expression: String = "neutral"
) -> Texture2D:
	_ensure_loaded()
	var expr := expression.strip_edges().to_lower()
	if expr == "":
		expr = _default_expression()
	var role := _resolve_role(entity_key, entity_name)
	var portrait_key := _resolve_portrait_key(kind, entity_name, role, expr)
	var portraits: Dictionary = _manifest.get("portraits", {})
	var path := str(portraits.get(portrait_key, ""))
	if path == "":
		portrait_key = _fallback_key(kind)
		path = str(portraits.get(portrait_key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func layout_size() -> Vector2:
	_ensure_loaded()
	var layout: Dictionary = _manifest.get("layout", {})
	return Vector2(float(layout.get("width", 248.0)), float(layout.get("height", 180.0)))

static func _default_expression() -> String:
	var fallbacks: Dictionary = _manifest.get("fallbacks", {})
	return str(fallbacks.get("default_expression", "neutral"))

static func _fallback_key(kind: String) -> String:
	var fallbacks: Dictionary = _manifest.get("fallbacks", {})
	if kind == "player":
		return str(fallbacks.get("default_player", "player_human_neutral"))
	return str(fallbacks.get("default_npc", "npc_default_neutral"))

static func _resolve_role(entity_key: String, entity_name: String) -> String:
	if entity_key == "" and entity_name == "":
		return ""
	var anchor := NpcAnchorResolver.resolve(entity_key, entity_name)
	return str(anchor.get("role", ""))

static func _resolve_portrait_key(kind: String, entity_name: String, role: String, expression: String) -> String:
	var base := _resolve_portrait_base(kind, entity_name, role)
	if base == "":
		base = "player_human" if kind == "player" else "npc_default"
	var key := "%s_%s" % [base, expression]
	var portraits: Dictionary = _manifest.get("portraits", {})
	if portraits.has(key):
		return key
	return "%s_%s" % [base, _default_expression()]

static func _resolve_portrait_base(kind: String, entity_name: String, role: String) -> String:
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
		var matches: Variant = rule.get("name_match", [])
		if matches is Array and not (matches as Array).is_empty():
			var hit := false
			for frag_v in matches:
				if name_l.contains(str(frag_v).to_lower()):
					hit = true
					break
			if not hit:
				continue
		return str(rule.get("portrait_base", ""))
	return ""

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("PortraitRegistry: manifest absent %s" % MANIFEST_PATH)
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		_manifest = raw
