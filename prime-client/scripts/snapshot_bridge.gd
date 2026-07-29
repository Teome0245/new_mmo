# snapshot_bridge.gd — M1/M2 : snapshots ia_bridge ou zone_feed.json -> EntityManager
extends Node

@export var entity_manager_path: NodePath = NodePath("../EntityManager")
@export var main_path: NodePath = NodePath("..")
@export var config_path: String = "res://config/snapshot_paths.json"

var _em: EntityManager = null
var _main: Node = null
var _timer: float = 0.0
var _interval: float = 1.0
var _paths: Dictionary = {}
var _live: bool = false
var _demo_loaded: bool = false
var _live_until: float = 0.0
var _managed_oids: Dictionary = {}
var _paused: bool = false


func set_paused(paused: bool) -> void:
	_paused = paused
	if paused:
		print("[SnapshotBridge] pause (WS live)")


func _ready() -> void:
	_em = get_node_or_null(entity_manager_path) as EntityManager
	_main = get_node_or_null(main_path)
	_load_config()
	call_deferred("_poll", 0.0)

func _load_config() -> void:
	if not FileAccess.file_exists(config_path):
		push_warning("SnapshotBridge: config absente %s" % config_path)
		return
	var f := FileAccess.open(config_path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		_paths = raw
		_interval = float(_paths.get("poll_interval_s", 1.0))

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _interval:
		_timer = 0.0
		_poll(delta)

func notify_live_packet() -> void:
	_live_until = Time.get_ticks_msec() / 1000.0 + 2.0

func _is_network_live() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _live_until

func _poll(_delta: float) -> void:
	if _em == null or _paused:
		return
	if _is_network_live():
		return
	var payload: Dictionary = _read_zone_feed_json()
	if payload.is_empty():
		payload = _read_raw_snapshots()
	if payload.is_empty() and bool(_paths.get("use_demo_if_empty", false)) and not _demo_loaded:
		payload = _read_demo()
		_demo_loaded = true
	if payload.is_empty():
		return
	_apply_payload(payload)

func _read_zone_feed_json() -> Dictionary:
	if not bool(_paths.get("prefer_zone_feed_json", true)):
		return {}
	var p := str(_paths.get("zone_feed_json", ""))
	if p == "" or not FileAccess.file_exists(p):
		return {}
	return _parse_json_file(p)

func _read_raw_snapshots() -> Dictionary:
	var entities: Array = []
	var player_p := str(_paths.get("player_snapshots", ""))
	var npc_p := str(_paths.get("npc_snapshots", ""))
	if player_p != "" and FileAccess.file_exists(player_p):
		entities.append_array(_players_from_snapshot(player_p))
	if npc_p != "" and FileAccess.file_exists(npc_p):
		entities.append_array(_npcs_from_snapshot(npc_p))
	if entities.is_empty():
		return {}
	return {"entities": entities, "ts": Time.get_unix_time_from_system()}

func _read_demo() -> Dictionary:
	var p := str(_paths.get("demo_entities", "res://assets/demo_entities.json"))
	if not FileAccess.file_exists(p):
		return {}
	print("[SnapshotBridge] mode demo — %s" % p)
	return _parse_json_file(p)

func _parse_json_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return raw if raw is Dictionary else {}

func _players_from_snapshot(path: String) -> Array:
	var doc: Dictionary = _parse_json_file(path)
	var players: Variant = doc.get("players", doc)
	if not players is Dictionary:
		return []
	var out: Array = []
	for key in (players as Dictionary).keys():
		var snap: Variant = (players as Dictionary)[key]
		if not snap is Dictionary:
			continue
		var s: Dictionary = snap
		if s.get("online") == false:
			continue
		var name := str(s.get("firstname", s.get("player", key)))
		out.append({
			"id": "player:%s" % name,
			"kind": "player",
			"name": name,
			"x": float(s.get("x", 0.0)),
			"y": float(s.get("y", 0.0)),
			"z": float(s.get("z", 0.0)),
			"online": true,
			"zone": str(s.get("zone", "")),
		})
	return out

func _npcs_from_snapshot(path: String) -> Array:
	var doc: Dictionary = _parse_json_file(path)
	var out: Array = []
	for key in doc.keys():
		var snap: Variant = doc[key]
		if not snap is Dictionary:
			continue
		var s: Dictionary = snap
		if s.get("x") == null:
			continue
		if s.get("online") == false:
			continue
		var name := str(s.get("display_name", s.get("name", key)))
		out.append({
			"id": "npc:%s" % key,
			"kind": "npc",
			"name": name,
			"x": float(s.get("x", 0.0)),
			"y": float(s.get("y", 0.0)),
			"z": float(s.get("z", 0.0)),
			"online": true,
			"zone": str(s.get("zone", "")),
		})
	return out

func _apply_payload(payload: Dictionary) -> void:
	var ents: Variant = payload.get("entities", [])
	if not ents is Array:
		return
	var players_only := bool(_paths.get("players_only", false))
	var seen_oids: Dictionary = {}
	for item: Variant in ents:
		if not item is Dictionary:
			continue
		var e: Dictionary = item
		var kind := str(e.get("kind", "object"))
		if players_only and kind != "player":
			continue
		var eid := str(e.get("id", e.get("name", "")))
		if eid == "":
			continue
		var oid := _hash_id(eid)
		seen_oids[oid] = true
		var label := str(e.get("name", eid))
		var col := _color_for_kind(kind, label)
		var raw := Vector3(
			float(e.get("x", 0.0)),
			float(e.get("y", 0.0)),
			float(e.get("z", 0.0))
		)
		var pos := Projection3D2D.normalize_core3_pos(raw)
		if _em.get_entity(oid) == null:
			_em.spawn(oid, pos, col, label, kind, eid)
		else:
			var existing := _em.get_entity(oid)
			if existing and existing.entity_key == "":
				existing.set_entity_key(eid)
			_em.move(oid, pos)
	for oid: Variant in _managed_oids.keys():
		if not seen_oids.has(oid):
			_em.despawn(int(oid))
			_managed_oids.erase(oid)
	for oid: Variant in seen_oids.keys():
		_managed_oids[oid] = true
	if not _live:
		_live = true
		if _main and _main.has_method("on_snapshot_feed_active"):
			_main.on_snapshot_feed_active()
		print("[SnapshotBridge] %d entité(s) live" % (ents as Array).size())

func _hash_id(s: String) -> int:
	return Crc32Util.entity_oid(s)

func _color_for_kind(kind: String, name: String = "") -> Color:
	if kind == "player":
		var n := name.to_lower()
		if n in ["lia", "nix", "mira", "gally", "kael", "bot_ia"]:
			return Entity.COLOR_PLAYER_BOT
		return Entity.COLOR_PLAYER_OFFICIAL
	match kind:
		"npc":
			return Entity.COLOR_NPC
	return Entity.COLOR_OBJECT
