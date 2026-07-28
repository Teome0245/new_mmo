# hub_ground_layer.gd — Sol hub Lost Heaven (plaza sable + emprise village)
extends Node2D
class_name HubGroundLayer

const BUILDINGS_PATH := "res://assets/maps/lost_heaven_buildings.json"
const PROPS_PATH := "res://assets/maps/lost_heaven_props.json"

@export var visible_ground: bool = true
@export var padding_m: float = 48.0
@export var hub_fill_alpha: float = 0.18

var _anchor := Vector2(4749.0, -737.0)
var _plaza_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	reload()

func reload() -> void:
	_plaza_points = PackedVector2Array()
	_load_plaza_ring()
	queue_redraw()

func _load_plaza_ring() -> void:
	if not FileAccess.file_exists(PROPS_PATH):
		return
	var f := FileAccess.open(PROPS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return
	for item: Variant in (raw as Dictionary).get("paths", []):
		if not item is Dictionary:
			continue
		var p: Dictionary = item
		if str(p.get("id", "")) != "path:lh_plaza_ring":
			continue
		var pts: Variant = p.get("points", [])
		if not pts is Array:
			return
		for pt: Variant in pts as Array:
			if pt is Dictionary:
				var d: Dictionary = pt
				var scr := Projection3D2D.to_screen(Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0))))
				_plaza_points.append(scr)
		return

func _building_bounds() -> Dictionary:
	var min_x := 1.0e12
	var max_x := -1.0e12
	var min_z := 1.0e12
	var max_z := -1.0e12
	if not FileAccess.file_exists(BUILDINGS_PATH):
		return {"ok": false}
	var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return {"ok": false}
	var doc: Dictionary = raw
	if doc.get("anchor") is Dictionary:
		var a: Dictionary = doc["anchor"]
		_anchor = Vector2(float(a.get("x", _anchor.x)), float(a.get("z", _anchor.y)))
	var arr: Variant = doc.get("buildings", [])
	if not arr is Array:
		return {"ok": false}
	for item: Variant in arr:
		if not item is Dictionary:
			continue
		var b: Dictionary = item
		var cx := float(b.get("x", 0.0))
		var cz := float(b.get("z", 0.0))
		var half := float(b.get("size_m", 32.0)) * 0.5 + padding_m * 0.25
		min_x = minf(min_x, cx - half)
		max_x = maxf(max_x, cx + half)
		min_z = minf(min_z, cz - half)
		max_z = maxf(max_z, cz + half)
	if min_x > max_x:
		return {"ok": false}
	return {
		"ok": true,
		"min_x": min_x - padding_m,
		"max_x": max_x + padding_m,
		"min_z": min_z - padding_m,
		"max_z": max_z + padding_m,
	}

func _draw() -> void:
	if not visible_ground:
		return
	var b := _building_bounds()
	if not b.get("ok", false):
		return
	var tl := Projection3D2D.to_screen(Vector3(float(b["min_x"]), 0.0, float(b["min_z"])))
	var br := Projection3D2D.to_screen(Vector3(float(b["max_x"]), 0.0, float(b["max_z"])))
	var rect := Rect2(tl, br - tl)
	# Teinte légère — laisser voir la texture planète (satellite) en dessous
	draw_rect(rect, Color(0.36, 0.28, 0.18, hub_fill_alpha))
	draw_rect(rect, Color(0.72, 0.52, 0.28, clampf(hub_fill_alpha + 0.22, 0.0, 0.65)), false, 2.0)
	# Plaza centrale plus claire
	if _plaza_points.size() >= 3:
		draw_colored_polygon(_plaza_points, Color(0.70, 0.54, 0.34, 0.62))
		draw_polyline(_plaza_points, Color(0.92, 0.72, 0.38, 0.75), 2.2, true)
	var center := Projection3D2D.to_screen(Vector3(_anchor.x, 0.0, _anchor.y))
	draw_circle(center, 7.0, Color(0.95, 0.75, 0.35, 0.95))
	draw_arc(center, 16.0, 0.0, TAU, 28, Color(0.95, 0.75, 0.35, 0.5), 1.8)
	_draw_desert_grain(rect)

func _draw_desert_grain(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4749037
	var count := int(rect.get_area() / 900.0)
	count = clampi(count, 40, 280)
	for _i in range(count):
		var px := rng.randf_range(rect.position.x, rect.end.x)
		var py := rng.randf_range(rect.position.y, rect.end.y)
		var tone := rng.randf_range(0.08, 0.18)
		draw_circle(Vector2(px, py), rng.randf_range(0.6, 1.8), Color(tone, tone * 0.85, tone * 0.6, 0.35))

func set_visible_ground(on: bool) -> void:
	visible_ground = on
	queue_redraw()
