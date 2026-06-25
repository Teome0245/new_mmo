# main.gd — Scene principale Prime Client (Godot 4.6)
extends Node2D

@onready var camera:         Camera2D      = $Camera2D
@onready var entity_manager: EntityManager = $EntityManager
@onready var info_label:     Label         = $UI/InfoPanel/VBox/InfoLabel
@onready var stats_label:    Label         = $UI/InfoPanel/VBox/StatsLabel

const CAM_SPEED:     float   = 400.0
const CAM_ZOOM_STEP: float   = 0.15
const CAM_ZOOM_MIN:  Vector2 = Vector2(0.05, 0.05)
const CAM_ZOOM_MAX:  Vector2 = Vector2(8.0, 8.0)

var _cam_target:  Vector2 = Vector2.ZERO
var _frame_count: int     = 0

func _ready() -> void:
	_demo_spawn()
	_update_info()

# ---------------------------------------------------------------------------
# Demo M2
# ---------------------------------------------------------------------------
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
	camera.zoom = (camera.zoom + Vector2(step, step)).clamp(CAM_ZOOM_MIN, CAM_ZOOM_MAX)

# ---------------------------------------------------------------------------
# UI debug
# ---------------------------------------------------------------------------
func _update_info() -> void:
	var center := camera.get_screen_center_position()
	var core3  := Projection3D2D.from_screen(center)
	if info_label:
		info_label.text = (
			"Prime Client v0.1  |  Godot 4.6  |  Entites: %d\n" % entity_manager.count() +
			"Zoom: %.2fx   Core3 cam: (%.0f, -, %.0f)" % [camera.zoom.x, core3.x, core3.z]
		)
	if stats_label:
		stats_label.text = "[ZQSD] camera  [Molette] zoom  [R] reset  [F] focus bot  [Ctrl+M] carte  [Esc] quitter"

# ---------------------------------------------------------------------------
# API reseau — appelee par NetworkBridge
# ---------------------------------------------------------------------------
func on_data_transform(object_id: int, x: float, y: float, z: float) -> void:
	entity_manager.move(object_id, Vector3(x, y, z))

func on_object_destroy(object_id: int) -> void:
	entity_manager.despawn(object_id)

func on_zone_change() -> void:
	entity_manager.clear()
