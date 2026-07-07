# zone_layers.gd — M4.3 eau + collision (polygones Core3 x/z)
extends Node2D
class_name ZoneLayers

const ZONES_PATH := "res://assets/maps/tatooine_zones.json"

@export var show_water: bool = true
@export var show_collision: bool = true

var _water: Array = []
var _collision: Array = []

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(ZONES_PATH):
		return
	var f := FileAccess.open(ZONES_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var doc: Dictionary = raw
		_water = doc.get("water", []) if doc.get("water") is Array else []
		_collision = doc.get("collision", []) if doc.get("collision") is Array else []
	queue_redraw()

func _draw() -> void:
	if show_water:
		for item: Variant in _water:
			_draw_poly(item, Color(0.15, 0.45, 0.85, 0.35), Color(0.3, 0.7, 1.0, 0.55))
	if show_collision:
		for item: Variant in _collision:
			_draw_poly(item, Color(0.5, 0.15, 0.1, 0.2), Color(0.9, 0.35, 0.2, 0.7), false)

func _draw_poly(item: Variant, fill: Color, outline: Color, filled: bool = true) -> void:
	if not item is Dictionary:
		return
	var poly: Variant = (item as Dictionary).get("polygon", [])
	if not poly is Array or (poly as Array).size() < 3:
		return
	var pts := PackedVector2Array()
	for p: Variant in poly:
		if not p is Array or (p as Array).size() < 2:
			continue
		var a: Array = p
		var wx := float(a[0])
		var wz := float(a[1])
		pts.append(Projection3D2D.to_screen(Vector3(wx, 0.0, wz)))
	if pts.size() < 3:
		return
	if filled:
		draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.5)

func toggle_water() -> void:
	show_water = not show_water
	queue_redraw()

func toggle_collision() -> void:
	show_collision = not show_collision
	queue_redraw()
