# player_controller.gd — Contrôles joueur Godot -> prime_controller.py
# =====================================================================
# M4.1 : ZQSD (AZERTY) / WASD (QWERTY)  -> DataTransform ZoneServer
# M4.2 : Espace -> saut
# M4.3 : Shift+Espace en eau -> nage montée / descente
#
# Ce script capture les inputs clavier Godot et envoie des commandes JSON
# via UDP local (port 12346) à prime_controller.py qui construit et émet
# les vrais paquets SOE/Core3.
#
# Nœud parent attendu : Main (Node2D) qui contient aussi EntityManager.
extends Node
class_name PlayerController

# Port UDP de prime_controller.py (CommandServer)
const CMD_PORT: int = 12346

# Vitesse de rotation de la caméra (rad/s) pour le suivi du joueur
const CAM_FOLLOW_SPEED: float = 5.0

@export var enabled: bool = true
@export var follow_camera: bool = true  # la Camera2D suit le joueur

var _udp:      PacketPeerUDP = PacketPeerUDP.new()
var _camera:   Camera2D      = null
var _em:       EntityManager = null
var _player_id: int          = 0   # object_id du personnage (set par bridge)

# États actifs (pour détecter les changements et envoyer que les deltas)
var _state := {
"fwd":   false,
"back":  false,
"left":  false,
"right": false,
"run":   false,
}

# Mapping action -> touche physique (AZERTY Z=fwd, Q=left; QWERTY W=fwd, A=left)
const ACTION_KEYS := {
"fwd":   [KEY_Z, KEY_W],
"back":  [KEY_S],
"left":  [KEY_Q, KEY_A],
"right": [KEY_D],
}

func _ready() -> void:
_udp.set_dest_address("127.0.0.1", CMD_PORT)
_camera = get_node_or_null("../Camera2D")
_em     = get_node_or_null("../EntityManager")
if not enabled:
return
print("[PlayerCtrl] Actif — UDP commands -> 127.0.0.1:%d" % CMD_PORT)

## Appelé par NetworkBridge quand le bridge reçoit un spawn du propre joueur
func set_player_id(obj_id: int) -> void:
_player_id = obj_id
print("[PlayerCtrl] Player obj_id = 0x%016x" % _player_id)

func _process(delta: float) -> void:
if not enabled:
return
_handle_movement()
_handle_jump()
_follow_player()

# ---------------------------------------------------------------------------
# Gestion déplacement (M4.1)
# ---------------------------------------------------------------------------
func _handle_movement() -> void:
for action in ["fwd", "back", "left", "right"]:
var pressed := _is_action_pressed(action)
if pressed != _state[action]:
_state[action] = pressed
_send({"t": action, "active": pressed})

# Run (Shift)
var running := Input.is_physical_key_pressed(KEY_SHIFT)
if running != _state["run"]:
_state["run"] = running
_send({"t": "run", "active": running})

# ---------------------------------------------------------------------------
# Saut et nage (M4.2 / M4.3)
# ---------------------------------------------------------------------------
func _handle_jump() -> void:
if Input.is_physical_key_pressed(KEY_SPACE):
# Shift + Espace en eau = nage vers le haut
if Input.is_physical_key_pressed(KEY_SHIFT):
_send({"t": "swim_up", "active": true})
elif Input.is_physical_key_pressed(KEY_CTRL):
_send({"t": "swim_down", "active": true})
else:
_send({"t": "jump", "active": true})
else:
# Relâchement
_send({"t": "swim_up",   "active": false})
_send({"t": "swim_down", "active": false})

# ---------------------------------------------------------------------------
# Suivi caméra (M4.1 — caméra sur le joueur)
# ---------------------------------------------------------------------------
func _follow_player() -> void:
if not follow_camera or not _camera or _player_id == 0 or not _em:
return
var player_entity := _em.get_entity(_player_id)
if player_entity:
_camera.position = _camera.position.lerp(
player_entity.position, CAM_FOLLOW_SPEED * get_process_delta_time()
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _is_action_pressed(action: String) -> bool:
var keys: Array = ACTION_KEYS.get(action, [])
for k in keys:
if Input.is_physical_key_pressed(k):
return true
return false

func _send(obj: Dictionary) -> void:
var data := JSON.stringify(obj).to_utf8_buffer()
_udp.put_packet(data)

## Envoie la position initiale du joueur à prime_controller.py
## (appelé par main.gd quand SceneCreateObjectByName donne la pos de spawn)
func send_initial_position(x: float, y: float, z: float) -> void:
_send({"t": "pos", "x": x, "y": y, "z": z})
print("[PlayerCtrl] Position initiale envoyée: (%.2f, %.2f, %.2f)" % [x, y, z])

func _exit_tree() -> void:
_send({"t": "stop"})
