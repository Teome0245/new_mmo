# player_controller.gd — ZQSD/Espace/Nage -> UDP:12346 -> prime_controller.py
extends Node
class_name PlayerController

const CMD_PORT:        int   = 12346
const CAM_FOLLOW_SPEED: float = 5.0

@export var enabled:       bool = true
@export var follow_camera: bool = true

var _udp:       PacketPeerUDP = PacketPeerUDP.new()
var _camera:    Camera2D      = null
var _em:        EntityManager = null
var _player_id: int           = 0

var _state: Dictionary = {
	"fwd":   false,
	"back":  false,
	"left":  false,
	"right": false,
	"run":   false,
}

const _KEY_MAP: Dictionary = {
	"fwd":   [KEY_Z, KEY_W],
	"back":  [KEY_S],
	"left":  [KEY_Q, KEY_A],
	"right": [KEY_D],
}

func _ready() -> void:
	_udp.set_dest_address("127.0.0.1", CMD_PORT)
	_camera = get_node_or_null("../Camera2D")
	_em     = get_node_or_null("../EntityManager")
	if enabled:
		print("[PlayerCtrl] Actif — UDP -> 127.0.0.1:%d" % CMD_PORT)

func set_player_id(obj_id: int) -> void:
	_player_id = obj_id

func _process(_delta: float) -> void:
	if not enabled:
		return
	_handle_movement()
	_handle_jump()
	_follow_player()

func _handle_movement() -> void:
	for action in _KEY_MAP:
		var pressed := false
		for k: int in _KEY_MAP[action]:
			if Input.is_physical_key_pressed(k):
				pressed = true
		if pressed != _state[action]:
			_state[action] = pressed
			_send({"t": action, "active": pressed})
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	if running != _state["run"]:
		_state["run"] = running
		_send({"t": "run", "active": running})

func _handle_jump() -> void:
	if Input.is_physical_key_pressed(KEY_SPACE):
		if Input.is_physical_key_pressed(KEY_SHIFT):
			_send({"t": "swim_up", "active": true})
		elif Input.is_physical_key_pressed(KEY_CTRL):
			_send({"t": "swim_down", "active": true})
		else:
			_send({"t": "jump", "active": true})
	else:
		_send({"t": "swim_up",   "active": false})
		_send({"t": "swim_down", "active": false})

func _follow_player() -> void:
	if not follow_camera or not _camera or _player_id == 0 or not _em:
		return
	var e := _em.get_entity(_player_id)
	if e:
		_camera.position = _camera.position.lerp(
			e.position, CAM_FOLLOW_SPEED * get_process_delta_time()
		)

func _send(obj: Dictionary) -> void:
	_udp.put_packet(JSON.stringify(obj).to_utf8_buffer())

func send_initial_position(x: float, y: float, z: float) -> void:
	_send({"t": "pos", "x": x, "y": y, "z": z})

func _exit_tree() -> void:
	_send({"t": "stop"})
