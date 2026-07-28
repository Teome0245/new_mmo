# zone_layers.gd — M4.3 eau + collision (polygones Core3 x/z) + hub Lost Heaven
extends Node2D
class_name ZoneLayers

const ZONES_PATH := "res://assets/maps/tatooine_zones.json"
const BUILDINGS_PATH := "res://assets/maps/lost_heaven_buildings.json"
const PROPS_PATH := "res://assets/maps/lost_heaven_props.json"

@export var show_water: bool = true
@export var show_collision: bool = true
@export var enforce_hub_fence: bool = true
@export var enforce_building_blocks: bool = true

var _water: Array = []
var _collision: Array = []
var _fence_ring: PackedVector2Array = PackedVector2Array()
var _gate_exits: Array = []
var _open_fence_segments: Dictionary = {}
var _building_blocks: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	_load()
	_load_hub_data()
	_load_hub_building_blocks()
	queue_redraw()

func _load() -> void:
	_water.clear()
	_collision.clear()
	if not FileAccess.file_exists(ZONES_PATH):
		return
	var f := FileAccess.open(ZONES_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var doc: Dictionary = raw
		_water = doc.get("water", []) if doc.get("water") is Array else []
		_collision = doc.get("collision", []) if doc.get("collision") is Array else []

func _load_hub_data() -> void:
	_fence_ring = PackedVector2Array()
	_gate_exits.clear()
	_open_fence_segments.clear()
	if not FileAccess.file_exists(PROPS_PATH):
		return
	var f := FileAccess.open(PROPS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return
	var doc: Dictionary = raw
	var gates: Variant = doc.get("gate_exits", [])
	if gates is Array:
		_gate_exits = gates
		for item: Variant in _gate_exits:
			if not item is Dictionary:
				continue
			var g: Dictionary = item
			var idxs: Variant = g.get("fence_open_segment_indices", [])
			if idxs is Array:
				for idx: Variant in idxs:
					_open_fence_segments[int(idx)] = true
	for item: Variant in doc.get("paths", []):
		if not item is Dictionary:
			continue
		var p: Dictionary = item
		if str(p.get("id", "")) != "path:lh_perimeter_fence":
			continue
		var pts: Variant = p.get("points", [])
		if not pts is Array:
			return
		for pt: Variant in pts as Array:
			if pt is Dictionary:
				var d: Dictionary = pt
				_fence_ring.append(Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0))))
		return

func _load_hub_building_blocks() -> void:
	_building_blocks.clear()
	if not enforce_building_blocks or not FileAccess.file_exists(BUILDINGS_PATH):
		return
	var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return
	for item: Variant in (raw as Dictionary).get("buildings", []):
		if not item is Dictionary:
			continue
		var b: Dictionary = item
		var kind := str(b.get("kind", ""))
		if kind == "city_gate":
			continue
		var cx := float(b.get("x", 0.0))
		var cz := float(b.get("z", 0.0))
		var half := float(b.get("size_m", 32.0)) * 0.5
		_building_blocks.append({
			"id": str(b.get("id", b.get("kind", "building"))),
			"min_x": cx - half,
			"max_x": cx + half,
			"min_z": cz - half,
			"max_z": cz + half,
		})

func _inside_hub_area(x: float, z: float) -> bool:
	if _fence_ring.size() < 3:
		return false
	return _point_in_polygon(Vector2(x, z), _fence_ring)

func _in_gate_corridor(x: float, z: float) -> bool:
	for item: Variant in _gate_exits:
		if not item is Dictionary:
			continue
		var g: Dictionary = item
		var c: Variant = g.get("center", {})
		if not c is Dictionary:
			continue
		var d: Dictionary = c
		var gx := float(d.get("x", 0.0))
		var gz := float(d.get("z", 0.0))
		var hw := float(g.get("width_m", 16.0)) * 0.5
		var north := float(g.get("depth_north_m", g.get("depth_m", 32.0)))
		var south := float(g.get("depth_south_m", g.get("depth_m", 32.0)))
		if absf(x - gx) <= hw and z <= gz + north and z >= gz - south:
			return true
	return false

func _fence_segment_open(seg_index: int) -> bool:
	if _open_fence_segments.has(seg_index):
		return true
	for item: Variant in _gate_exits:
		if not item is Dictionary:
			continue
		var g: Dictionary = item
		var c: Variant = g.get("center", {})
		if not c is Dictionary:
			continue
		var cd: Dictionary = c
		var gx := float(cd.get("x", 0.0))
		var gz := float(cd.get("z", 0.0))
		var hw := float(g.get("width_m", 16.0)) * 0.55
		if _fence_ring.size() < 2:
			continue
		var n := _fence_ring.size()
		var i := seg_index % n
		var j := (i + 1) % n
		var mx := (_fence_ring[i].x + _fence_ring[j].x) * 0.5
		var mz := (_fence_ring[i].y + _fence_ring[j].y) * 0.5
		if absf(mx - gx) <= hw and absf(mz - gz) <= 55.0:
			return true
	return false

func _crosses_blocked_fence(from: Vector3, to: Vector3) -> bool:
	if not enforce_hub_fence or _fence_ring.size() < 3:
		return false
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var n := _fence_ring.size()
	for i in range(n):
		if _fence_segment_open(i):
			continue
		var p1 := _fence_ring[i]
		var p2 := _fence_ring[(i + 1) % n]
		if _segments_intersect(a, b, p1, p2):
			return true
	return false

func allows_core3(x: float, z: float) -> bool:
	if not _allows_global_zones(x, z):
		return false
	if _inside_hub_area(x, z) or _in_gate_corridor(x, z):
		for block: Variant in _building_blocks:
			if not block is Dictionary:
				continue
			var box: Dictionary = block
			if x >= float(box["min_x"]) and x <= float(box["max_x"]) and z >= float(box["min_z"]) and z <= float(box["max_z"]):
				return false
	return true

func clamp_move(from: Vector3, to: Vector3) -> Vector3:
	if _crosses_blocked_fence(from, to):
		return _slide_along_blocks(from, to)
	if allows_core3(to.x, to.z):
		return to
	return _slide_along_blocks(from, to)

func _slide_along_blocks(from: Vector3, to: Vector3) -> Vector3:
	var tx := Vector3(to.x, from.y, from.z)
	if not _crosses_blocked_fence(from, tx) and allows_core3(tx.x, tx.z):
		return tx
	var tz := Vector3(from.x, from.y, to.z)
	if not _crosses_blocked_fence(from, tz) and allows_core3(tz.x, tz.z):
		return tz
	return from

func _allows_global_zones(x: float, z: float) -> bool:
	for item: Variant in _collision:
		if not item is Dictionary:
			continue
		var poly: Variant = (item as Dictionary).get("polygon", [])
		if _point_in_json_poly(x, z, poly):
			return false
	return true

func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return _orient(a, b, c) * _orient(a, b, d) < 0.0 and _orient(c, d, a) * _orient(c, d, b) < 0.0

func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

func _point_in_json_poly(x: float, z: float, poly: Variant) -> bool:
	if not poly is Array or (poly as Array).size() < 3:
		return false
	var pts := PackedVector2Array()
	for p: Variant in poly:
		if p is Array and (p as Array).size() >= 2:
			var arr: Array = p
			pts.append(Vector2(float(arr[0]), float(arr[1])))
	return _point_in_polygon(Vector2(x, z), pts)

func _point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var n := poly.size()
	if n < 3:
		return false
	var j := n - 1
	for i in range(n):
		var pi := poly[i]
		var pj := poly[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y + 1e-9) + pi.x):
			inside = not inside
		j = i
	return inside

func _draw() -> void:
	if show_water:
		for item: Variant in _water:
			_draw_poly(item, Color(0.15, 0.45, 0.85, 0.35), Color(0.3, 0.7, 1.0, 0.55))
	if show_collision:
		for item: Variant in _collision:
			_draw_poly(item, Color(0.5, 0.15, 0.1, 0.2), Color(0.9, 0.35, 0.2, 0.7), false)
		if _fence_ring.size() >= 3:
			var scr := PackedVector2Array()
			for v in _fence_ring:
				scr.append(Projection3D2D.to_screen(Vector3(v.x, 0.0, v.y)))
			draw_colored_polygon(scr, Color(0.2, 0.85, 0.35, 0.06))
			var n := _fence_ring.size()
			for i in range(n):
				var p1 := Projection3D2D.to_screen(Vector3(_fence_ring[i].x, 0.0, _fence_ring[i].y))
				var p2 := Projection3D2D.to_screen(Vector3(_fence_ring[(i + 1) % n].x, 0.0, _fence_ring[(i + 1) % n].y))
				var col := Color(0.95, 0.75, 0.25, 0.85) if _fence_segment_open(i) else Color(0.3, 0.9, 0.45, 0.45)
				var w := 2.2 if _fence_segment_open(i) else 1.2
				draw_line(p1, p2, col, w)
		for item: Variant in _gate_exits:
			if not item is Dictionary:
				continue
			var g: Dictionary = item
			var c: Variant = g.get("center", {})
			if not c is Dictionary:
				continue
			var d: Dictionary = c
			var gx := float(d.get("x", 0.0))
			var gz := float(d.get("z", 0.0))
			var hw := float(g.get("width_m", 16.0)) * 0.5
			var north := float(g.get("depth_north_m", g.get("depth_m", 32.0)))
			var south := float(g.get("depth_south_m", g.get("depth_m", 32.0)))
			var tl := Projection3D2D.to_screen(Vector3(gx - hw, 0.0, gz - south))
			var br := Projection3D2D.to_screen(Vector3(gx + hw, 0.0, gz + north))
			var rect := Rect2(tl, br - tl)
			draw_rect(rect, Color(0.95, 0.75, 0.25, 0.08))
			draw_rect(rect, Color(0.95, 0.8, 0.35, 0.55), false, 1.0)
		for block: Variant in _building_blocks:
			if not block is Dictionary:
				continue
			var box: Dictionary = block
			var tl := Projection3D2D.to_screen(Vector3(float(box["min_x"]), 0.0, float(box["min_z"])))
			var br := Projection3D2D.to_screen(Vector3(float(box["max_x"]), 0.0, float(box["max_z"])))
			var rect := Rect2(tl, br - tl)
			draw_rect(rect, Color(0.9, 0.25, 0.15, 0.12))
			draw_rect(rect, Color(0.95, 0.4, 0.2, 0.55), false, 1.0)

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

# Compat ancien export
var enforce_hub_walkable: bool:
	get:
		return enforce_hub_fence
	set(v):
		enforce_hub_fence = v
