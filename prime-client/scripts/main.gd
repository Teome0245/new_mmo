# main.gd — Scène principale Prime Client
# ========================================
# Contrôle la caméra 2D, l'UI de debug et le cycle de vie de la session.
# Reçoit les événements réseau via NetworkBridge (M3) et les délègue à EntityManager.
extends Node2D

# ---- Références aux enfants ----
@onready var camera:         Camera2D       = $Camera2D
@onready var entity_manager: EntityManager  = $EntityManager
@onready var info_label:     Label          = $UI/InfoPanel/InfoLabel
@onready var stats_label:    Label          = $UI/InfoPanel/StatsLabel

# ---- Paramètres caméra ----
const CAM_SPEED:      float = 400.0   # pixels/seconde (monde)
const CAM_ZOOM_STEP:  float = 0.15
const CAM_ZOOM_MIN:   Vector2 = Vector2(0.05, 0.05)
const CAM_ZOOM_MAX:   Vector2 = Vector2(8.0,  8.0)

var _cam_target: Vector2 = Vector2.ZERO
var _frame_count: int    = 0

func _ready() -> void:
_demo_spawn()
_update_info()

# ---------------------------------------------------------------------------
# Entités de démonstration (M2 — sans réseau)
# ---------------------------------------------------------------------------
func _demo_spawn() -> void:
# Client SWG officiel (bleu) — position fictive Tatooine Mos Eisley
entity_manager.spawn(0x0000_0001_0000_0001,
Vector3(3500.0, 0.0, -4800.0),
Entity.COLOR_PLAYER_OFFICIAL,
"SWG_Client")

# Bot IA (vert)
entity_manager.spawn(0x0000_0001_0000_0002,
Vector3(3510.0, 0.0, -4795.0),
Entity.COLOR_PLAYER_BOT,
"Bot_IA")

# NPC orange — exemple en l'air (saut)
entity_manager.spawn(0x0000_0002_0000_0001,
Vector3(3525.0, 8.0, -4810.0),
Entity.COLOR_NPC,
"NPC_Guard")

# Centre de carte (repère)
entity_manager.spawn(0,
Vector3(0.0, 0.0, 0.0),
Color(1.0, 1.0, 0.0, 0.6),
"(0,0)")

# Centrer la caméra sur Mos Eisley
var center_screen := Projection3D2D.to_screen(Vector3(3510.0, 0.0, -4800.0))
camera.position = center_screen
_cam_target     = center_screen

# ---------------------------------------------------------------------------
# Entrées clavier / souris
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
# Zoom molette souris
if event is InputEventMouseButton:
if event.pressed:
if event.button_index == MOUSE_BUTTON_WHEEL_UP:
_zoom_camera(CAM_ZOOM_STEP)
elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
_zoom_camera(-CAM_ZOOM_STEP)

# Raccourcis clavier
if event is InputEventKey and event.pressed:
match event.keycode:
KEY_R:   # Reset vue
camera.zoom     = Vector2.ONE
camera.position = _cam_target
KEY_F:   # Focus sur l'entité 1 (bot IA)
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
# ZQSD (azerty) et WASD (qwerty)
if Input.is_action_pressed("cam_up")    or Input.is_physical_key_pressed(KEY_W): dir.y -= 1.0
if Input.is_action_pressed("cam_down")  or Input.is_physical_key_pressed(KEY_S): dir.y += 1.0
if Input.is_action_pressed("cam_left")  or Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
if Input.is_action_pressed("cam_right") or Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
if Input.is_action_pressed("zoom_in"):  _zoom_camera(CAM_ZOOM_STEP * delta * 4.0)
if Input.is_action_pressed("zoom_out"): _zoom_camera(-CAM_ZOOM_STEP * delta * 4.0)

if dir != Vector2.ZERO:
camera.position += dir.normalized() * CAM_SPEED * delta / camera.zoom.x

func _zoom_camera(step: float) -> void:
camera.zoom = (camera.zoom + Vector2(step, step)).clamp(CAM_ZOOM_MIN, CAM_ZOOM_MAX)

# ---------------------------------------------------------------------------
# UI de debug
# ---------------------------------------------------------------------------
func _update_info() -> void:
var mouse_world := camera.get_screen_center_position()
var core3       := Projection3D2D.from_screen(mouse_world)
info_label.text = (
"Prime Client v0.1  |  M2 Skeleton\n" +
"Zoom: %.2fx  |  Entités: %d\n" % [camera.zoom.x, entity_manager.count()] +
"Caméra: (%.0f, %.0f) screen → Core3 (%.0f, %.0f, %.0f)" % [
mouse_world.x, mouse_world.y,
core3.x, core3.y, core3.z
]
)
stats_label.text = (
"[ZQSD] déplacer  [Molette] zoom  [R] reset  [F] focus bot  [Esc] quitter"
)

# ---------------------------------------------------------------------------
# API réseau — sera appelée par NetworkBridge en M3
# ---------------------------------------------------------------------------

## Reçu du bridge : une entité bouge (DataTransform).
func on_data_transform(object_id: int, x: float, y: float, z: float) -> void:
entity_manager.move(object_id, Vector3(x, y, z))

## Reçu du bridge : une entité disparaît.
func on_object_destroy(object_id: int) -> void:
entity_manager.despawn(object_id)

## Reçu du bridge : changement de zone.
func on_zone_change() -> void:
entity_manager.clear()
