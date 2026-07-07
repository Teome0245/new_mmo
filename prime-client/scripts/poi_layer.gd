# poi_layer.gd — Marqueurs POI carte Tatooine (M4)
extends Node2D
class_name PoiLayer

const POI_PATH := "res://assets/maps/tatooine_pois.json"
const DETAIL_ZOOM_MIN: float = 1.75

@export var visible_pois: bool = true
@export var show_detail_pois: bool = false
@export var camera_path: NodePath = NodePath("../../Camera2D")

var _pois: Array = []

func _ready() -> void:
	_load_pois()

func _process(_delta: float) -> void:
	queue_redraw()

func _load_pois() -> void:
	if not FileAccess.file_exists(POI_PATH):
		push_warning("PoiLayer: %s absent — lance export_tatooine_for_godot.py" % POI_PATH)
		return
	var f := FileAccess.open(POI_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var arr: Variant = (raw as Dictionary).get("pois", [])
		_pois = arr if arr is Array else []

func _cam_zoom() -> float:
	var cam := get_node_or_null(camera_path) as Camera2D
	return cam.zoom.x if cam else 1.0

func _show_detail() -> bool:
	return show_detail_pois or _cam_zoom() >= DETAIL_ZOOM_MIN

func _draw() -> void:
	if not visible_pois:
		return
	var detail := _show_detail()
	var zoom := _cam_zoom()
	for item: Variant in _pois:
		if not item is Dictionary:
			continue
		var p: Dictionary = item
		if bool(p.get("deprecated", false)):
			continue
		var essential := bool(p.get("essential", false))
		if bool(p.get("detail", false)) and not essential and not detail:
			continue
		var pos := Projection3D2D.to_screen(
			Vector3(float(p.get("x", 0.0)), 0.0, float(p.get("z", 0.0)))
		)
		var kind := str(p.get("kind", ""))
		var col := _color_for_kind(kind)
		var r := 5.0 if bool(p.get("detail", false)) and not essential else 7.0
		draw_circle(pos, r + 2.0, Color(col.r, col.g, col.b, 0.2))
		draw_circle(pos, r, col)
		var label := str(p.get("label", ""))
		if label == "":
			continue
		# Libellés bâtiments seulement si zoom suffisant
		if bool(p.get("detail", false)) and not essential and zoom < 2.5:
			continue
		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-label.length() * 2.5, -r - 6.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9 if bool(p.get("detail", false)) else 10,
			Color(1.0, 0.95, 0.85, 0.9)
		)

func _color_for_kind(kind: String) -> Color:
	match kind:
		"spawn":
			return Color(0.2, 1.0, 0.4, 1.0)
		"city":
			return Color(0.95, 0.75, 0.2, 1.0)
		"hub":
			return Color(0.3, 0.85, 1.0, 1.0)
		"cantina", "inn":
			return Color(1.0, 0.45, 0.2, 1.0)
		"starport_shuttle":
			return Color(0.5, 1.0, 0.5, 1.0)
		"bank":
			return Color(0.95, 0.82, 0.25, 1.0)
		"shops", "market":
			return Color(1.0, 0.55, 0.2, 1.0)
		"terminal", "blue_frog":
			return Color(0.35, 0.75, 1.0, 1.0)
	return Color(0.7, 0.7, 0.8, 0.9)

func set_visible_pois(on: bool) -> void:
	visible_pois = on
	queue_redraw()

func toggle_detail_pois() -> void:
	show_detail_pois = not show_detail_pois
	print("[PoiLayer] détail bâtiments: %s" % ("ON" if show_detail_pois else "OFF"))
	queue_redraw()
