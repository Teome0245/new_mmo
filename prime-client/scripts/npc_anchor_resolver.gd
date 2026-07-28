# npc_anchor_resolver.gd — Résout ancres PNJ Lost Heaven (data-driven)
class_name NpcAnchorResolver

const ANCHORS_PATH := "res://assets/maps/lost_heaven_npc_anchors.json"
const BUILDINGS_PATH := "res://assets/maps/lost_heaven_buildings.json"

static var _loaded: bool = false
static var _defaults: Dictionary = {}
static var _anchors: Array = []
static var _buildings: Dictionary = {}  # id -> {x,z}
static var _salt: String = "lost_heaven_v1"

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_buildings()
	_load_anchors()

static func _load_buildings() -> void:
	_buildings.clear()
	if not FileAccess.file_exists(BUILDINGS_PATH):
		return
	var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return
	var arr: Variant = (raw as Dictionary).get("buildings", [])
	if not arr is Array:
		return
	for item: Variant in arr:
		if item is Dictionary:
			var b: Dictionary = item
			_buildings[str(b.get("id", ""))] = {
				"x": float(b.get("x", 0.0)),
				"z": float(b.get("z", 0.0)),
			}

static func _load_anchors() -> void:
	_anchors.clear()
	_defaults.clear()
	if not FileAccess.file_exists(ANCHORS_PATH):
		return
	var f := FileAccess.open(ANCHORS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return
	var doc: Dictionary = raw
	_defaults = doc.get("behavior_defaults", {}) if doc.get("behavior_defaults") is Dictionary else {}
	var seed_cfg: Variant = _defaults.get("seed", {})
	if seed_cfg is Dictionary:
		_salt = str((seed_cfg as Dictionary).get("salt", _salt))
	var arr: Variant = doc.get("anchors", [])
	_anchors = arr if arr is Array else []

static func normalize_pilot_id(raw_id: String) -> String:
	var s := raw_id.strip_edges()
	# zone_feed: "npc:npc:core3_…" → "npc:core3_…"
	while s.begins_with("npc:npc:"):
		s = "npc:" + s.substr(8)
	if not s.begins_with("npc:") and s.begins_with("core3_"):
		s = "npc:" + s
	return s

static func seed_u32(pilot_id: String) -> int:
	var key := "%s|%s" % [pilot_id, _salt]
	return int(Crc32Util.entity_oid(key) & 0x7fff_ffff)

static func resolve(entity_key: String, label: String = "") -> Dictionary:
	ensure_loaded()
	var pilot := normalize_pilot_id(entity_key)
	var best: Dictionary = {}
	for item: Variant in _anchors:
		if not item is Dictionary:
			continue
		var a: Dictionary = item
		var m: Variant = a.get("match", {})
		if not m is Dictionary:
			continue
		var md: Dictionary = m
		if md.has("pilot_id"):
			if normalize_pilot_id(str(md.get("pilot_id"))) == pilot:
				best = a
				break
		elif md.has("name_pattern") and label != "":
			var pat := str(md.get("name_pattern"))
			if label.to_lower().contains(pat.to_lower()):
				best = a
	if best.is_empty():
		return {}
	return _enrich(best, pilot)

static func _enrich(anchor: Dictionary, pilot_id: String) -> Dictionary:
	var out := anchor.duplicate(true)
	var bid := str(anchor.get("building_id", ""))
	var bx := 0.0
	var bz := 0.0
	if _buildings.has(bid):
		bx = float(_buildings[bid].get("x", 0.0))
		bz = float(_buildings[bid].get("z", 0.0))
	var off: Variant = anchor.get("offset_m", {})
	var ox := 0.0
	var oz := 0.0
	if off is Dictionary:
		ox = float((off as Dictionary).get("x", 0.0))
		oz = float((off as Dictionary).get("z", 0.0))
	out["_home_x"] = bx + ox
	out["_home_z"] = bz + oz
	out["_pilot_id"] = pilot_id
	out["_seed"] = seed_u32(pilot_id)
	# merge bob defaults
	var bob_def: Dictionary = _defaults.get("idle_bob", {}) if _defaults.get("idle_bob") is Dictionary else {}
	var bob: Dictionary = bob_def.duplicate()
	if anchor.get("idle_bob") is Dictionary:
		bob.merge(anchor.get("idle_bob") as Dictionary, true)
	out["_bob"] = bob
	var pat_def: Dictionary = _defaults.get("patrol", {}) if _defaults.get("patrol") is Dictionary else {}
	var pat: Dictionary = pat_def.duplicate()
	if anchor.get("patrol") is Dictionary:
		pat.merge(anchor.get("patrol") as Dictionary, true)
	out["_patrol"] = pat
	return out
