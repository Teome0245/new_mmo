# player_controller.gd — ZQSD/Espace/Nage -> UDP:12346 et/ou LbgWsClient move
extends Node
class_name PlayerController

const CMD_PORT:        int   = 12346
const CAM_FOLLOW_SPEED: float = 5.0
const PLAY_CFG:        String = "res://config/play_mode.json"
const MOVE_SPEED:      float = 16.0
const RUN_MULT:        float = 1.75
const _LastPos = preload("res://scripts/last_position_store.gd")

@export var enabled:       bool = false
@export var follow_camera: bool = true
@export var cmd_host:      String = "127.0.0.1"
@export var cmd_port:      int   = CMD_PORT
@export var prefer_ws_move: bool = true

var _udp:       PacketPeerUDP = PacketPeerUDP.new()
var _camera:    Camera2D      = null
var _em:        EntityManager = null
var _player_id: int           = 0
var _ws:        Node          = null
var _move_accum: float        = 0.0
var _zones:     ZoneLayers    = null

var _state: Dictionary = {
	"fwd":   false,
	"back":  false,
	"left":  false,
	"right": false,
	"run":   false,
}

const _KEY_MAP: Dictionary = {
	"fwd":   [KEY_Z, KEY_W, KEY_UP],
	"back":  [KEY_S, KEY_DOWN],
	"left":  [KEY_Q, KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
}

const _CLICK_ARRIVE_M: float = 0.45
var _click_target: Vector3 = Vector3.INF

func _ready() -> void:
	_load_play_cfg()
	_udp.set_dest_address(cmd_host, cmd_port)
	_camera = get_node_or_null("../Camera2D")
	_em     = get_node_or_null("../EntityManager")
	_zones  = get_node_or_null("../WorldMap/ZoneLayers") as ZoneLayers
	if enabled:
		print("[PlayerCtrl] Actif — UDP -> %s:%d" % [cmd_host, cmd_port])

func _load_play_cfg() -> void:
	if not FileAccess.file_exists(PLAY_CFG):
		return
	var f := FileAccess.open(PLAY_CFG, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var cfg: Dictionary = raw
		var h := str(cfg.get("cmd_host", "")).strip_edges()
		if h != "":
			cmd_host = h
		cmd_port = int(cfg.get("cmd_port", cmd_port))

func set_player_id(obj_id: int) -> void:
	_player_id = obj_id

func set_ws_client(ws: Node) -> void:
	_ws = ws

func get_player_id() -> int:
	return _player_id

func _process(delta: float) -> void:
	if not enabled:
		return
	_handle_movement()
	_handle_jump()
	_apply_ws_locomotion(delta)
	_apply_click_move(delta)
	_follow_player()

func _ws_open() -> bool:
	return prefer_ws_move and _ws != null and _ws.has_method("is_open") and bool(_ws.is_open())

func _handle_movement() -> void:
	var any_key := false
	for action in _KEY_MAP:
		var pressed: bool = false
		for k: int in _KEY_MAP[action]:
			if Input.is_physical_key_pressed(k):
				pressed = true
		if pressed:
			any_key = true
		if pressed != _state[action]:
			_state[action] = pressed
			if not _ws_open():
				_send({"t": action, "active": pressed})
	if any_key:
		_click_target = Vector3.INF
	var running: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	if running != _state["run"]:
		_state["run"] = running
		if not _ws_open():
			_send({"t": "run", "active": running})

func _apply_ws_locomotion(delta: float) -> void:
	if _player_id == 0 or _em == null:
		return
	var dir := Vector3.ZERO
	# Écran : Z=haut, S=bas, Q=gauche, D=droite → Core3 X est / Z nord
	if _state["fwd"]:
		dir.z += 1.0
	if _state["back"]:
		dir.z -= 1.0
	if _state["left"]:
		dir.x -= 1.0
	if _state["right"]:
		dir.x += 1.0
	if dir == Vector3.ZERO:
		return
	dir = dir.normalized()
	var speed := MOVE_SPEED * (RUN_MULT if _state["run"] else 1.0)
	var e: Entity = _em.get_entity(_player_id)
	if e == null:
		return
	# Toujours core3_pos (pas from_screen) : position écran inclut jitter/bob → dérive diagonale.
	var core3: Vector3 = e.core3_pos
	core3.x += dir.x * speed * delta
	core3.z += dir.z * speed * delta
	if _zones:
		core3 = _zones.clamp_move(e.core3_pos, core3)
	_em.move(_player_id, core3)
	_move_accum += delta
	if _move_accum >= 0.05:
		_move_accum = 0.0
		if _ws_open() and _ws.has_method("send_move"):
			_ws.send_move(core3)
		if not _ws_open():
			_send({"t": "pos", "x": core3.x, "y": core3.y, "z": core3.z})
		_LastPos.save(_player_id, core3)


func is_moving() -> bool:
	return bool(_state["fwd"] or _state["back"] or _state["left"] or _state["right"]) or _click_target != Vector3.INF


func set_click_target(core3: Vector3) -> void:
	_click_target = core3


func _apply_click_move(delta: float) -> void:
	if _click_target == Vector3.INF or _player_id == 0 or _em == null:
		return
	var e: Entity = _em.get_entity(_player_id)
	if e == null:
		return
	var to := _click_target - e.core3_pos
	to.y = 0.0
	var dist := to.length()
	if dist < _CLICK_ARRIVE_M:
		_click_target = Vector3.INF
		return
	var dir := to / dist
	var speed := MOVE_SPEED * (RUN_MULT if _state["run"] else 1.0)
	var step := minf(dist, speed * delta)
	var core3 := e.core3_pos + dir * step
	if _zones:
		core3 = _zones.clamp_move(e.core3_pos, core3)
	_em.move(_player_id, core3)
	_move_accum += delta
	if _move_accum >= 0.05:
		_move_accum = 0.0
		if _ws_open() and _ws.has_method("send_move"):
			_ws.send_move(core3)
		if not _ws_open():
			_send({"t": "pos", "x": core3.x, "y": core3.y, "z": core3.z})
		_LastPos.save(_player_id, core3)

func _handle_jump() -> void:
	if _ws_open():
		return
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
	var e: Entity = _em.get_entity(_player_id)
	if e:
		_camera.position = _camera.position.lerp(
			e.position, CAM_FOLLOW_SPEED * get_process_delta_time()
		)

func _send(obj: Dictionary) -> void:
	_udp.put_packet(JSON.stringify(obj).to_utf8_buffer())

func send_initial_position(x: float, y: float, z: float) -> void:
	if _ws_open() and _ws.has_method("send_move"):
		_ws.send_move(Vector3(x, y, z))
		return
	_send({"t": "pos", "x": x, "y": y, "z": z})

func request_move_to(x: float, z: float) -> void:
	set_click_target(Vector3(x, 0.0, z))

func _exit_tree() -> void:
	if not _ws_open():
		_send({"t": "stop"})
