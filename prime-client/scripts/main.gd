# main.gd — Scene principale Prime Client (Godot 4.6)
extends Node2D

@onready var camera:         Camera2D      = $Camera2D
@onready var entity_manager: EntityManager = $EntityManager
@onready var info_label:     Label         = $UI/InfoPanel/VBox/InfoLabel
@onready var stats_label:    Label         = $UI/InfoPanel/VBox/StatsLabel
@onready var state_label:    Label         = $UI/StatePanel/StateLabel

const CAM_SPEED:     float   = 400.0
const CAM_ZOOM_STEP: float   = 0.15
const CAM_ZOOM_MIN:  Vector2 = Vector2(0.05, 0.05)
const CAM_ZOOM_MAX:  Vector2 = Vector2(8.0, 8.0)

@export var allow_demo_fallback: bool = false
@export var camera_free_pan: bool = true

var _cam_target:   Vector2 = Vector2.ZERO
var _play_mode:    bool    = false
var _frame_count:  int     = 0
var _planet_name:  String  = ""         # planete courante (M5)
var _loco_state:   String  = "STANDING" # etat locomotion (M5)
var _is_connected: bool    = false       # vrai quand un vrai joueur est connecté
var _snapshot_live: bool  = false
var _udp_live: bool       = false

const FOCUS_BOTS: Array[String] = ["Nix", "Lia", "Mira"]
const FOCUS_ZOOM: Vector2 = Vector2(2.0, 2.0)

const LOST_HEAVEN_HUB := Vector3(4749.0, 0.0, -737.0)
const LOST_HEAVEN_ZOOM: Vector2 = Vector2(1.8, 1.8)

func _ready() -> void:
	# Demo M2 : SnapshotBridge charge demo_entities.json si pas de snapshots
	get_tree().create_timer(0.35).timeout.connect(_maybe_demo_spawn)
	call_deferred("_focus_lost_heaven_hub")
	_update_info()

func _focus_lost_heaven_hub() -> void:
	if camera == null:
		return
	var center := Projection3D2D.to_screen(LOST_HEAVEN_HUB)
	camera.position = center
	camera.zoom = LOST_HEAVEN_ZOOM
	_cam_target = center
	print("[Main] focus Lost Heaven hub (4749, -737)")

# ---------------------------------------------------------------------------
# Demo M2 (fallback si SnapshotBridge sans données)
# ---------------------------------------------------------------------------
func _maybe_demo_spawn() -> void:
	if not allow_demo_fallback:
		return
	if _snapshot_live or _udp_live or entity_manager.count() > 0:
		return
	_demo_spawn()

func _demo_spawn() -> void:
	entity_manager.spawn(
		0x0000_0001_0000_0001,
		Vector3(3500.0, 0.0, -4800.0),
		Entity.COLOR_PLAYER_OFFICIAL,
		"SWG_Client"
	)
	entity_manager.spawn(
		0x0000_0001_0000_0002,
		Vector3(3510.0, 0.0, -4795.0),
		Entity.COLOR_PLAYER_BOT,
		"Bot_IA"
	)
	entity_manager.spawn(
		0x0000_0002_0000_0001,
		Vector3(3525.0, 8.0, -4810.0),
		Entity.COLOR_NPC,
		"NPC_Guard"
	)
	entity_manager.spawn(0, Vector3(0.0, 0.0, 0.0), Color(1.0, 1.0, 0.0, 0.6), "(0,0)")
	var center := Projection3D2D.to_screen(Vector3(3510.0, 0.0, -4800.0))
	camera.position = center
	_cam_target     = center

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(CAM_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-CAM_ZOOM_STEP)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				_focus_bot("Lia")
			KEY_F2:
				_focus_bot("Nix")
			KEY_F3:
				_focus_bot("Mira")
			KEY_H:
				_focus_lost_heaven_hub()
			KEY_R:
				camera.zoom     = Vector2.ONE
				camera.position = _cam_target
			KEY_F:
				var e := entity_manager.get_entity(0x0000_0001_0000_0002)
				if e:
					camera.position = e.position
			KEY_ESCAPE:
				get_tree().quit()

func _process(delta: float) -> void:
	_handle_camera_move(delta)
	_frame_count += 1
	if _frame_count % 60 == 0:
		_update_info()

func _handle_camera_move(delta: float) -> void:
	if camera == null or _play_mode or not camera_free_pan:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_EQUAL):
		_zoom_camera(CAM_ZOOM_STEP * delta * 4.0)
	if Input.is_key_pressed(KEY_MINUS):
		_zoom_camera(-CAM_ZOOM_STEP * delta * 4.0)
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAM_SPEED * delta / camera.zoom.x

func _zoom_camera(step: float) -> void:
	if camera == null:
		return
	camera.zoom = (camera.zoom + Vector2(step, step)).clamp(CAM_ZOOM_MIN, CAM_ZOOM_MAX)

# ---------------------------------------------------------------------------
# UI debug
# ---------------------------------------------------------------------------
func _update_info() -> void:
	if camera == null:
		return
	var center := camera.get_screen_center_position()
	var core3  := Projection3D2D.from_screen(center)
	if info_label:
		var mode := "PLAY" if _play_mode else ("UDP LIVE" if _udp_live else ("PRIME" if _snapshot_live else "ATTENTE"))
		var players := entity_manager.count()
		info_label.text = (
			"Prime Client v0.2  |  %s  |  Bots: %d\n" % [mode, players] +
			"Zoom: %.2fx   Core3 cam: (%.0f, -, %.0f)" % [camera.zoom.x, core3.x, core3.z]
		)
	if stats_label:
		if _play_mode:
			stats_label.text = "[ZQSD] joueur  [Shift] run  [Espace] saut  [Ctrl+M] carte  [Esc] quit"
		else:
			stats_label.text = "[H] hub LH  [F1/F2/F3] bots  [Ctrl+M] carte  [Ctrl+P] POI  [Ctrl+H] bât.  [Esc] quit"

# ---------------------------------------------------------------------------
# API reseau — appelee par NetworkBridge
# ---------------------------------------------------------------------------
func on_data_transform(object_id: int, x: float, y: float, z: float) -> void:
	entity_manager.move(object_id, Vector3(x, y, z))

func on_object_destroy(object_id: int) -> void:
	entity_manager.despawn(object_id)

func on_zone_change() -> void:
	entity_manager.clear()
	_is_connected = false

func on_mirror_udp_active() -> void:
	_udp_live = true
	_snapshot_live = true
	_update_info()

func on_snapshot_feed_active() -> void:
	_snapshot_live = true
	_update_info()
	# Garder la vue hub Lost Heaven ; F1/F2/F3 pour cibler un bot
	call_deferred("_focus_lost_heaven_hub")
	print("[Main] flux snapshot actif — Ctrl+H hub · F1/F2/F3 bots")

func _focus_bot(name: String) -> bool:
	if camera == null:
		return false
	var oid := Crc32Util.entity_oid("player:%s" % name)
	var e := entity_manager.get_entity(oid)
	if e == null:
		print("[Main] focus %s : absent — lance run_m3_mirror.sh ?" % name)
		return false
	camera.position = e.position
	camera.zoom = FOCUS_ZOOM
	_cam_target = e.position
	print("[Main] focus %s" % name)
	return true

func _focus_first_bot() -> void:
	for name in FOCUS_BOTS:
		if _focus_bot(name):
			return

# M5 — Joueur connecté (reçu via NetworkBridge "cn")
func on_player_connected(obj_id: int, planet: String) -> void:
	_planet_name  = planet
	_is_connected = true
	_play_mode    = true
	camera_free_pan = false
	var pc: PlayerController = get_node_or_null("PlayerController") as PlayerController
	if pc:
		pc.enabled = true
		pc.set_player_id(obj_id)
	if state_label:
		state_label.text = "CONNECTED"
	_update_info()
	print("[Main] Joueur 0x%016x connecté sur %s" % [obj_id, planet])

# M5 — Etat locomotion depuis prime_controller.py ("ls")
func on_locomotion_state(state: String) -> void:
	_loco_state = state.to_upper()
	if state_label:
		state_label.text = _loco_state
		# Couleur selon l'etat
		match _loco_state:
			"RUNNING":  state_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
			"JUMPING","FALLING": state_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
			"SWIMMING": state_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1))
			"WALKING":  state_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
			_:          state_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
