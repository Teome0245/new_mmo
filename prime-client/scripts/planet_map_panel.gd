# planet_map_panel.gd — Carte planétaire plein écran Ctrl+M (M9c, style SWG)
extends Control
class_name PlanetMapPanel

const POI_PATH := "res://assets/maps/tatooine_pois.json"
const LOC_PATH := "res://assets/maps/locations_tree.json"
const MAP_CONFIG := "res://assets/maps/tatooine_map_config.json"
const HUB := Vector3(4749.0, 0.0, -737.0)

@export var camera_path: NodePath = NodePath("../../../Camera2D")
@export var player_controller_path: NodePath = NodePath("../../../PlayerController")

var _open: bool = false
var _pan: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _half_size: float = 6500.0
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _pan_start: Vector2 = Vector2.ZERO
var _last_click_ms: int = 0

var _texture: Texture2D
var _pois: Array = []
var _locations: Array = []
var _waypoints: Array = []
var _hover_label: String = ""

@onready var _title: Label = $Panel/VBox/TitleLabel
@onready var _hint: Label = $Panel/VBox/HintLabel
@onready var _chrome: Control = $Panel

func _ready() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_chrome()
	_load_config()
	_load_texture()
	_load_data()
	if _title:
		_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72, 1))
	if _hint:
		_hint.text = "Ctrl+M fermer · molette zoom · double-clic aller · Shift+clic waypoint · clic-droit suppr. · F centrer hub"
		_hint.add_theme_color_override("font_color", Color(0.72, 0.62, 0.48, 1))

func reload_data() -> void:
	_load_data()
	queue_redraw()

func is_open() -> bool:
	return _open

func open_map() -> void:
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_chrome()
	_waypoints = WaypointStore.load_all()
	_zoom = 1.0
	_pan = Vector2.ZERO
	queue_redraw()

func close_map() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_chrome()

func _sync_chrome() -> void:
	if _chrome:
		_chrome.visible = _open

func toggle_map() -> void:
	if _open:
		close_map()
	else:
		open_map()

func _focus_core3(core3: Vector3) -> void:
	var rect := _map_rect()
	var local := _core3_to_local(core3, rect)
	_pan = rect.size * 0.5 - local * _zoom
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and event.ctrl_pressed:
			toggle_map()
			get_viewport().set_input_as_handled()
			return
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_focus_core3(HUB)
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.12)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.12)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.shift_pressed:
					var core3 := _screen_to_core3(mb.position)
					var res := WaypointStore.add_waypoint("", core3.x, core3.z)
					if res.get("ok"):
						_waypoints = WaypointStore.load_all()
						queue_redraw()
				else:
					var now := Time.get_ticks_msec()
					if now - _last_click_ms < 350:
						_go_to(_screen_to_core3(mb.position))
					_last_click_ms = now
				_dragging = true
				_drag_start = mb.position
				_pan_start = _pan
			else:
				_dragging = false
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var hit := _pick_waypoint(mb.position)
			if hit != "":
				WaypointStore.remove_waypoint(hit)
				_waypoints = WaypointStore.load_all()
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			_pan = _pan_start + (mm.position - _drag_start)
			queue_redraw()
		else:
			_hover_label = _pick_poi_label(mm.position)
			queue_redraw()

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var rect := _map_rect()
	var before := (screen_pos - rect.position - _pan) / _zoom
	_zoom = clampf(_zoom * factor, 0.35, 4.0)
	_pan = screen_pos - rect.position - before * _zoom
	queue_redraw()

func _load_config() -> void:
	if not FileAccess.file_exists(MAP_CONFIG):
		return
	var f := FileAccess.open(MAP_CONFIG, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		_half_size = float((raw as Dictionary).get("half_size", _half_size))

func _load_texture() -> void:
	_texture = MapTextureLoader.load_texture("planet_map")
	if _texture:
		return
	for path in [
		"res://assets/maps/tatooine.png",
		"res://assets/maps/tatooine_satellite.webp",
		"res://assets/maps/tatooine.svg",
	]:
		if ResourceLoader.exists(path):
			_texture = load(path) as Texture2D
			if _texture:
				return

func _load_data() -> void:
	_pois = _read_array(POI_PATH, "pois")
	_locations = _read_array(LOC_PATH, "locations")
	_waypoints = WaypointStore.load_all()

func _read_array(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var arr: Variant = (raw as Dictionary).get(key, [])
		return arr if arr is Array else []
	return []

func _map_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var margin := 40.0
	var top := 68.0
	return Rect2(margin, top, vp.x - margin * 2.0, vp.y - top - margin - 28.0)

func _core3_to_local(core3: Vector3, rect: Rect2) -> Vector2:
	var nx := core3.x / _half_size
	var nz := -core3.z / _half_size
	return Vector2((nx + 1.0) * 0.5 * rect.size.x, (nz + 1.0) * 0.5 * rect.size.y)

func _screen_to_core3(screen_pos: Vector2) -> Vector3:
	var rect := _map_rect()
	var local := (screen_pos - rect.position - _pan) / _zoom
	var nx := (local.x / rect.size.x) * 2.0 - 1.0
	var ny := (local.y / rect.size.y) * 2.0 - 1.0
	return Vector3(nx * _half_size, 0.0, -ny * _half_size)

func _core3_to_screen(core3: Vector3) -> Vector2:
	var rect := _map_rect()
	var local := _core3_to_local(core3, rect)
	return rect.position + _pan + local * _zoom

func _pick_waypoint(screen_pos: Vector2) -> String:
	for item: Variant in _waypoints:
		if not item is Dictionary:
			continue
		var wp: Dictionary = item
		var p := _core3_to_screen(Vector3(float(wp.get("x", 0)), 0, float(wp.get("z", 0))))
		if p.distance_to(screen_pos) <= 10.0:
			return str(wp.get("id", ""))
	return ""

func _pick_poi_label(screen_pos: Vector2) -> String:
	for item: Variant in _pois:
		if not item is Dictionary:
			continue
		var p: Dictionary = item
		if bool(p.get("deprecated", false)):
			continue
		var pos := _core3_to_screen(Vector3(float(p.get("x", 0)), 0, float(p.get("z", 0))))
		if pos.distance_to(screen_pos) <= 14.0:
			return str(p.get("label", p.get("id", "")))
	return ""

func _go_to(core3: Vector3) -> void:
	var pc := get_node_or_null(player_controller_path) as PlayerController
	if pc and pc.enabled:
		pc.request_move_to(core3.x, core3.z)
	else:
		var cam := get_node_or_null(camera_path) as Camera2D
		if cam:
			cam.position = Projection3D2D.to_screen(core3)

func _poi_color(kind: String) -> Color:
	match kind:
		"hub":
			return Color(0.95, 0.72, 0.22, 1.0)
		"spawn", "starport_shuttle":
			return Color(0.45, 0.85, 1.0, 1.0)
		"city":
			return Color(0.92, 0.82, 0.55, 1.0)
		_:
			return Color(0.85, 0.65, 0.35, 0.95)

func _draw() -> void:
	if not _open:
		return
	# Fond space-western
	draw_rect(get_viewport_rect(), Color(0.05, 0.04, 0.03, 0.94))
	var rect := _map_rect()
	draw_rect(rect, Color(0.10, 0.08, 0.06, 0.98))
	draw_rect(rect, Color(0.72, 0.52, 0.28, 0.75), false, 2.0)

	# Texture planète : remplit le cadre, puis zoom/pan
	if _texture and _texture.get_size().x > 0.0:
		draw_set_transform(rect.position + _pan, 0.0, Vector2(_zoom, _zoom))
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, rect.size), false, Color(1, 1, 1, 0.96))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Lieux (villes / hub)
	for item: Variant in _locations:
		if not item is Dictionary:
			continue
		var loc: Dictionary = item
		if bool(loc.get("deprecated", false)):
			continue
		var pos := _core3_to_screen(Vector3(float(loc.get("x", 0)), 0, float(loc.get("z", 0))))
		if not rect.has_point(pos):
			continue
		var kind := str(loc.get("kind", ""))
		if kind == "hub":
			continue
		var col := _poi_color(kind if kind != "" else "city")
		draw_circle(pos, 6.0, col)
		draw_arc(pos, 9.0, 0.0, TAU, 20, col.lightened(0.2), 1.5)
		var lbl := str(loc.get("label", ""))
		if lbl != "":
			draw_string(
				ThemeDB.fallback_font,
				pos + Vector2(12, 4),
				lbl,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color(0.96, 0.90, 0.78, 0.95)
			)

	# POI essentiels
	for item: Variant in _pois:
		if not item is Dictionary:
			continue
		var p: Dictionary = item
		if bool(p.get("deprecated", false)):
			continue
		if not bool(p.get("essential", false)) and not bool(p.get("active", true)):
			continue
		var pos := _core3_to_screen(Vector3(float(p.get("x", 0)), 0, float(p.get("z", 0))))
		if not rect.has_point(pos):
			continue
		var kind := str(p.get("kind", ""))
		var col := _poi_color(kind)
		var r := 5.5 if kind == "hub" else 3.5
		draw_circle(pos, r, col)
		# Labels hub / villes seulement (évite le clutter)
		if kind == "hub" or kind == "city":
			var lbl := str(p.get("label", ""))
			if lbl != "":
				draw_string(
					ThemeDB.fallback_font,
					pos + Vector2(10, -6),
					lbl,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					12,
					Color(1.0, 0.92, 0.7, 0.95)
				)

	for item: Variant in _waypoints:
		if not item is Dictionary:
			continue
		var wp: Dictionary = item
		var pos := _core3_to_screen(Vector3(float(wp.get("x", 0)), 0, float(wp.get("z", 0))))
		draw_circle(pos, 6.0, Color(1.0, 0.45, 0.85, 1.0))
		var lbl := str(wp.get("label", ""))
		if lbl != "":
			draw_string(ThemeDB.fallback_font, pos + Vector2(8, -8), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))

	# Pied de carte
	var footer := _hover_label if _hover_label != "" else "Lost Heaven · Scrapaltai"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x + 8.0, get_viewport_rect().size.y - 18.0),
		footer,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(0.92, 0.82, 0.62, 1)
	)
