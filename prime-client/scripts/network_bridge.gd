# network_bridge.gd — Pont UDP local Python -> Godot (port 12345)
extends Node

const BIND_PORT: int = 12345

@export var entity_manager_path: NodePath = NodePath("../EntityManager")
@export var world_map_path:      NodePath = NodePath("../WorldMap")
@export var main_path:           NodePath = NodePath("..")

var _udp:       PacketPeerUDP = PacketPeerUDP.new()
var _em:        EntityManager = null
var _main:      Node          = null
var _active:    bool          = false
var _demo_cleared: bool       = false   # devient true à la première connexion live

func _ready() -> void:
	_em   = get_node_or_null(entity_manager_path)
	_main = get_node_or_null(main_path)
	var err: int = _udp.bind(BIND_PORT, "127.0.0.1")
	if err != OK:
		push_warning("NetworkBridge: port %d indisponible (err %d)" % [BIND_PORT, err])
		return
	_active = true
	print("[Bridge] En ecoute sur 127.0.0.1:%d" % BIND_PORT)

func _process(_delta: float) -> void:
	if not _active:
		return
	while _udp.get_available_packet_count() > 0:
		var raw: PackedByteArray = _udp.get_packet()
		var text: String         = raw.get_string_from_utf8()
		_dispatch(text)

func _dispatch(text: String) -> void:
	# JSON.parse_string retourne Variant — on type explicitement
	var pkt: Variant = JSON.parse_string(text)
	if not pkt is Dictionary:
		return
	var d: Dictionary = pkt as Dictionary
	match str(d.get("t", "")):
		"mv":
			if _em:
				_em.move(
					int(d.get("id", 0)),
					Vector3(float(d.get("x", 0.0)),
							float(d.get("y", 0.0)),
							float(d.get("z", 0.0)))
				)
		"sp":
			if _em:
				_em.spawn(
					int(d.get("id", 0)),
					Vector3(float(d.get("x", 0.0)),
							float(d.get("y", 0.0)),
							float(d.get("z", 0.0))),
					_parse_color(str(d.get("c", "npc"))),
					str(d.get("l", ""))
				)
		"dp":
			if _em:
				_em.despawn(int(d.get("id", 0)))
		"zc":
			if _em:
				_em.clear()
			_demo_cleared = true
			if _main and _main.has_method("on_zone_change"):
				_main.on_zone_change()
		# M5 — Joueur connecté : spawn + suivi caméra + clear demo
		"cn":
			if not _demo_cleared and _em:
				_em.clear()          # efface les entités demo
				_demo_cleared = true
			var oid := int(d.get("id", 0))
			var x   := float(d.get("x", 0.0))
			var y   := float(d.get("y", 0.0))
			var z   := float(d.get("z", 0.0))
			var pl  := str(d.get("pl", ""))
			if _em and oid != 0:
				_em.spawn(oid, Vector3(x, y, z), Entity.COLOR_PLAYER_OFFICIAL, "YOU")
			var pc: PlayerController = get_node_or_null("../PlayerController") as PlayerController
			if pc and oid != 0:
				pc.set_player_id(oid)
				pc.send_initial_position(x, y, z)
			if _main and _main.has_method("on_player_connected"):
				_main.on_player_connected(oid, pl)
			print("[Bridge] Joueur connecté: 0x%016x  planet=%s  pos=(%.1f,%.1f,%.1f)" % [oid, pl, x, y, z])
		# M5 — Etat locomotion → StateLabel
		"ls":
			if _main and _main.has_method("on_locomotion_state"):
				_main.on_locomotion_state(str(d.get("s", "STANDING")))
		"ws":
			_load_ws_json(str(d.get("path", "")))

func _load_ws_json(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var f: FileAccess      = FileAccess.open(path, FileAccess.READ)
	# Variant explicite — JSON.parse_string() ne retourne pas de type statique
	var raw: Variant       = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Array:
		return
	var data: Array = raw as Array
	for obj: Variant in data:
		if not obj is Dictionary:
			continue
		var o: Dictionary = obj as Dictionary
		if _em:
			_em.spawn(
				int(o.get("id", 0)),
				Vector3(float(o.get("x", 0.0)),
						float(o.get("y", 0.0)),
						float(o.get("z", 0.0))),
				Entity.COLOR_OBJECT,
				_short_tmpl(str(o.get("tmpl", "")))
			)
	print("[Bridge] %d objets ws charges" % data.size())

func _parse_color(c: String) -> Color:
	match c:
		"blue":   return Entity.COLOR_PLAYER_OFFICIAL
		"green":  return Entity.COLOR_PLAYER_BOT
		"orange": return Entity.COLOR_NPC
	return Entity.COLOR_OBJECT

func _short_tmpl(tmpl: String) -> String:
	var base: String = tmpl.get_file().get_basename()
	if base.begins_with("shared_"):
		base = base.substr(7)
	if base.length() > 20:
		return base.substr(0, 18) + ".."
	return base
