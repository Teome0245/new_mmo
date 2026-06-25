# network_bridge.gd — Pont UDP local Python -> Godot
# ===================================================
# M3.1 : Reçoit les paquets JSON de soe_handshake.py (localhost:12345)
#         et pilote l'EntityManager + le WorldMap.
#
# Protocole JSON (un objet par datagramme UDP) :
#   {"t":"mv",  "id":281474993487873, "x":3500.0, "y":0.0, "z":-4800.0}
#   {"t":"sp",  "id":..., "x":..., "y":..., "z":..., "c":"blue", "l":"Gally"}
#   {"t":"dp",  "id":...}
#   {"t":"zc",  "scene":"tatooine"}
#   {"t":"ws",  "path":"/path/to/tatooine.json"}   # bâtiments préchargés
extends Node

const BIND_PORT: int = 12345
const MAX_PKT:   int = 8192

@export var entity_manager_path: NodePath = "../EntityManager"
@export var world_map_path:      NodePath = "../WorldMap"
@export var main_path:           NodePath = ".."

var _udp:    PacketPeerUDP = PacketPeerUDP.new()
var _em:     EntityManager = null
var _main                  = null
var _active: bool          = false

func _ready() -> void:
_em   = get_node_or_null(entity_manager_path)
_main = get_node_or_null(main_path)

var err := _udp.bind(BIND_PORT, "127.0.0.1")
if err != OK:
push_warning("NetworkBridge: impossible d'écouter sur le port %d (err=%d)" % [BIND_PORT, err])
return

_active = true
print("[Bridge] En écoute sur 127.0.0.1:%d" % BIND_PORT)

func _process(_delta: float) -> void:
if not _active:
return

# Dépiler tous les paquets disponibles ce frame
while _udp.get_available_packet_count() > 0:
var raw   := _udp.get_packet()
var text  := raw.get_string_from_utf8()
_dispatch(text)

func _dispatch(text: String) -> void:
var pkt = JSON.parse_string(text)
if not pkt is Dictionary:
return

var t: String = pkt.get("t", "")

match t:
"mv":   # move / DataTransform
var obj_id := int(pkt.get("id", 0))
var x := float(pkt.get("x", 0.0))
var y := float(pkt.get("y", 0.0))
var z := float(pkt.get("z", 0.0))
if _em:
_em.move(obj_id, Vector3(x, y, z))

"sp":   # spawn
var obj_id := int(pkt.get("id", 0))
var x := float(pkt.get("x", 0.0))
var y := float(pkt.get("y", 0.0))
var z := float(pkt.get("z", 0.0))
var color  := _parse_color(pkt.get("c", "npc"))
var label  := str(pkt.get("l", ""))
if _em:
_em.spawn(obj_id, Vector3(x, y, z), color, label)

"dp":   # despawn
var obj_id := int(pkt.get("id", 0))
if _em:
_em.despawn(obj_id)

"zc":   # zone change
if _em:
_em.clear()
var scene := str(pkt.get("scene", ""))
if _main and _main.has_method("on_zone_change"):
_main.on_zone_change()
print("[Bridge] Zone change -> %s" % scene)

"ws":   # world snapshot JSON chargé par ws_parser.py
var path := str(pkt.get("path", ""))
_load_ws_json(path)

_:
pass   # paquet inconnu — ignorer silencieusement

# ---------------------------------------------------------------------------
# Chargement snapshot bâtiments (ws_parser.py output)
# ---------------------------------------------------------------------------
func _load_ws_json(path: String) -> void:
if path == "" or not FileAccess.file_exists(path):
push_warning("[Bridge] ws JSON introuvable : " + path)
return

var f    := FileAccess.open(path, FileAccess.READ)
var data := JSON.parse_string(f.get_as_text())
f.close()

if not data is Array:
return

# Chaque entrée : {"id": int, "x": float, "y": float, "z": float, "tmpl": "string"}
for obj in data:
if not obj is Dictionary:
continue
var obj_id := int(obj.get("id", 0))
var x      := float(obj.get("x", 0.0))
var y      := float(obj.get("y", 0.0))
var z      := float(obj.get("z", 0.0))
var tmpl   := str(obj.get("tmpl", ""))
if _em:
_em.spawn(obj_id, Vector3(x, y, z), Entity.COLOR_OBJECT, _short_tmpl(tmpl))

print("[Bridge] %d objets chargés depuis %s" % [data.size(), path.get_file()])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _parse_color(c: String) -> Color:
match c:
"blue":   return Entity.COLOR_PLAYER_OFFICIAL
"green":  return Entity.COLOR_PLAYER_BOT
"orange": return Entity.COLOR_NPC
_:        return Entity.COLOR_OBJECT

func _short_tmpl(tmpl: String) -> String:
# "object/building/tatooine/shared_mos_espa_tavern.iff" -> "mos_espa_tavern"
var base := tmpl.get_file().get_basename()
if base.begins_with("shared_"):
base = base.substr(7)
return base if base.length() <= 20 else base.substr(0, 18) + ".."

func close() -> void:
_udp.close()
_active = false
