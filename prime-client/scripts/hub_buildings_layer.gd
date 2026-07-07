# hub_buildings_layer.gd — Emprises bâtiments Lost Heaven (M8 Godot)
extends Node2D
class_name HubBuildingsLayer

const BUILDINGS_PATH := "res://assets/maps/lost_heaven_buildings.json"

@export var visible_buildings: bool = true

var _buildings: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	_buildings.clear()
	if not FileAccess.file_exists(BUILDINGS_PATH):
		push_warning("HubBuildingsLayer: %s absent — export_tatooine_for_godot.py" % BUILDINGS_PATH)
		return
	var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var arr: Variant = (raw as Dictionary).get("buildings", [])
		_buildings = arr if arr is Array else []
	queue_redraw()

func _draw() -> void:
	if not visible_buildings:
		return
	for item: Variant in _buildings:
		if not item is Dictionary:
			continue
		var b: Dictionary = item
		var cx := float(b.get("x", 0.0))
		var cz := float(b.get("z", 0.0))
		var size_m := float(b.get("size_m", 32.0))
		var half_px := size_m * 0.5 * Projection3D2D.SCALE
		var center := Projection3D2D.to_screen(Vector3(cx, 0.0, cz))
		var rect := Rect2(center - Vector2(half_px, half_px), Vector2(half_px * 2.0, half_px * 2.0))
		var kind := str(b.get("kind", ""))
		var fill := _color_for_kind(kind)
		draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.22))
		draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.85), false, 2.0)
		var label := str(b.get("label", ""))
		if label != "":
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-label.length() * 3.0, -half_px - 6.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				Color(1.0, 0.98, 0.9, 0.95)
			)

func _color_for_kind(kind: String) -> Color:
	match kind:
		"bank":
			return Color(0.95, 0.82, 0.25, 1.0)
		"shops", "market":
			return Color(1.0, 0.55, 0.2, 1.0)
		"terminal", "blue_frog":
			return Color(0.35, 0.75, 1.0, 1.0)
		"starport_shuttle":
			return Color(0.45, 0.95, 0.5, 1.0)
	return Color(0.65, 0.65, 0.75, 1.0)

func set_visible_buildings(on: bool) -> void:
	visible_buildings = on
	queue_redraw()
